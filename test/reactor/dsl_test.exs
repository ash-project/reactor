defmodule Reactor.DslTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Example.Step.Greeter
  alias Reactor.{Info, Step}
  alias Spark.Error.DslError

  describe "transforming steps" do
    test "steps with an implementation module compile correctly" do
      defmodule StepWithImplReactor do
        @moduledoc false
        use Reactor

        input :whom

        step :example, Greeter do
          argument :whom, input(:whom)
        end
      end

      step =
        StepWithImplReactor
        |> Info.to_struct!()
        |> Map.get(:steps, [])
        |> List.first()

      assert step.name == :example
      assert step.impl == {Greeter, []}
    end

    test "steps with function implementations compile correctly" do
      defmodule StepWithFnsReactor do
        @moduledoc false
        use Reactor

        input :whom

        step :example do
          argument :whom, input(:whom)

          run(fn %{whom: whom}, _ ->
            {:ok, "Hello, #{whom || "World"}!"}
          end)

          undo(fn _reason, _, _ ->
            :ok
          end)

          compensate(fn _result, _, _ ->
            :ok
          end)

          backoff(fn _result, _, _ ->
            :now
          end)
        end
      end

      step =
        StepWithFnsReactor
        |> Info.to_struct!()
        |> Map.get(:steps, [])
        |> List.first()

      assert step.name == :example
      assert {Step.AnonFn, opts} = step.impl
      assert is_function(opts[:run], 2)
      assert is_function(opts[:compensate], 3)
      assert is_function(opts[:undo], 3)
      assert is_function(opts[:backoff], 3)
    end

    test "steps with no implementation fail to compile" do
      assert_raise DslError, ~r/no implementation/, fn ->
        defmodule EmptyStepReactor do
          @moduledoc false
          use Reactor

          input :whom

          step :example do
            argument :whom, input(:whom)
          end
        end
      end
    end

    test "steps with impl and run fail to compile" do
      assert_raise DslError, ~r/both an implementation module and a run function/, fn ->
        defmodule DoubleImplRunReactor do
          @moduledoc false
          use Reactor

          input :whom

          step :example, Greeter do
            argument :whom, input(:whom)

            run(fn %{whom: whom}, _ ->
              {:ok, "Hello, #{whom || "World"}!"}
            end)
          end
        end
      end
    end

    test "steps with impl and undo fail to compile" do
      assert_raise DslError, ~r/both an implementation module and a undo function/, fn ->
        defmodule DoubleImplUndoReactor do
          @moduledoc false
          use Reactor

          input :whom

          step :example, Greeter do
            argument :whom, input(:whom)

            undo(fn _reason, _, _ ->
              :ok
            end)
          end
        end
      end
    end

    test "steps with impl and compensate fail to compile" do
      assert_raise DslError, ~r/both an implementation module and a compensate function/, fn ->
        defmodule DoubleImplCompensateReactor do
          @moduledoc false
          use Reactor

          input :whom

          step :example, Greeter do
            argument :whom, input(:whom)

            compensate(fn _result, _, _ ->
              :ok
            end)
          end
        end
      end
    end

    test "steps with impl and backoff fail to compile" do
      assert_raise DslError, ~r/both an implementation module and a backoff function/, fn ->
        defmodule DoubleImplBackoffReactor do
          @moduledoc false
          use Reactor

          input :whom

          step :example, Greeter do
            argument :whom, input(:whom)

            backoff(fn _result, _, _ ->
              :now
            end)
          end
        end
      end
    end
  end

  describe "middlewares" do
    test "middlewares can be added to a module" do
      defmodule ExampleMiddleware do
        @moduledoc false
        use Reactor.Middleware
      end

      defmodule MiddlewareReactor do
        @moduledoc false
        use Reactor

        middlewares do
          middleware ExampleMiddleware
        end

        step :noop do
          run fn _, _ -> {:ok, :noop} end
        end
      end

      middlewares =
        MiddlewareReactor.reactor()
        |> Map.fetch!(:middleware)

      assert middlewares == [ExampleMiddleware]
    end
  end

  describe "description" do
    test "descriptions can be added" do
      defmodule DescribedReactor do
        use Reactor

        description "A reactor that does nothing useful"

        step :noop do
          run fn _, _ -> {:ok, :noop} end
        end
      end

      assert "A reactor that does nothing useful" ==
               DescribedReactor.reactor() |> Map.fetch!(:description)
    end
  end
end
