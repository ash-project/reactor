defmodule Reactor.Executor.HooksTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.Builder

  describe "init" do
    defmodule ReturnContextReactor do
      @moduledoc false
      use Reactor

      step :return_context do
        run fn _args, context ->
          {:ok, context}
        end
      end
    end

    test "initialisation hooks can mutate the context" do
      defmodule MutateInitMiddleware do
        @moduledoc false
        @behaviour Reactor.Middleware

        def init(context) do
          {:ok, Map.put(context, :mutated?, true)}
        end
      end

      reactor =
        ReturnContextReactor.reactor()
        |> Builder.add_middleware!(MutateInitMiddleware)

      {:ok, context} = Reactor.run(reactor, %{}, %{mutated?: false})
      assert context.mutated?
    end
  end

  describe "halt" do
    defmodule HaltingReactor do
      @moduledoc false
      use Reactor

      step :halt do
        run fn _, _ ->
          {:halt, :because}
        end
      end
    end

    test "halt hooks can mutate the context" do
      defmodule MutateHaltMiddleware do
        @moduledoc false
        @behaviour Reactor.Middleware

        def halt(context) do
          {:ok, Map.put(context, :mutated?, true)}
        end
      end

      reactor =
        HaltingReactor.reactor()
        |> Builder.add_middleware!(MutateHaltMiddleware)

      {:halted, halted_reactor} = Reactor.run(reactor, %{}, %{mutated?: false})
      assert halted_reactor.context.mutated?
    end
  end

  describe "error" do
    defmodule ErrorReactor do
      @moduledoc false
      use Reactor

      step :fail do
        run &fail/2
      end

      def fail(_args, _context) do
        raise "hell"
      end
    end

    test "error hooks can mutate the error" do
      defmodule MutateErrorMiddleware do
        @moduledoc false
        @behaviour Reactor.Middleware

        def error(errors, _context) do
          [error] = List.wrap(errors)
          assert is_exception(error, RuntimeError)
          assert Exception.message(error) == "hell"

          {:error, :wat}
        end
      end

      reactor =
        ErrorReactor.reactor()
        |> Builder.add_middleware!(MutateErrorMiddleware)

      assert {:error, :wat} = Reactor.run(reactor, %{}, %{})
    end

    test "error hooks can see the context" do
      defmodule ErrorContextMiddleware do
        @moduledoc false
        @behaviour Reactor.Middleware

        def error(_errors, context) do
          assert context.is_context?

          :ok
        end
      end

      reactor =
        ErrorReactor.reactor()
        |> Builder.add_middleware!(ErrorContextMiddleware)

      assert {:error, [%RuntimeError{message: "hell"}]} =
               Reactor.run(reactor, %{}, %{is_context?: true})
    end
  end

  describe "complete" do
    defmodule SimpleReactor do
      @moduledoc false
      use Reactor

      step :succeed do
        run fn _, _ -> {:ok, :ok} end
      end
    end

    test "completion hooks can change the result" do
      defmodule CompleteMutateMiddleware do
        @moduledoc false
        @behaviour Reactor.Middleware

        def complete(result, _context) do
          assert result == :ok
          {:ok, :wat}
        end
      end

      reactor =
        SimpleReactor.reactor()
        |> Builder.add_middleware!(CompleteMutateMiddleware)

      assert {:ok, :wat} = Reactor.run(reactor, %{}, %{})
    end

    test "completion hooks can see the context" do
      defmodule CompleteContextMiddleware do
        @moduledoc false
        @behaviour Reactor.Middleware

        def complete(result, context) do
          assert context.is_context?

          {:ok, result}
        end
      end

      reactor =
        SimpleReactor.reactor()
        |> Builder.add_middleware!(CompleteContextMiddleware)

      assert {:ok, :ok} = Reactor.run(reactor, %{}, %{is_context?: true})
    end
  end
end
