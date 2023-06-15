defmodule Reactor.ContainerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.Error.ContainerError

  describe "behaviour verification" do
    test "when the container module has no callbacks defined" do
      assert_raise ContainerError, ~r/must define/i, fn ->
        defmodule EmptyContainer do
          @moduledoc false
          use Reactor.Container
        end
      end
    end

    test "when the container module has too many callbacks defined" do
      assert_raise ContainerError, ~r/in conjunction/i, fn ->
        defmodule TooManyCallbacksContainer do
          @moduledoc false
          use Reactor.Container

          def before_steps(_container_name, _steps), do: {:ok, nil}
          def after_steps(_container_name, _results), do: {:ok, nil}
          def around_steps(_container_name, _steps, _callback), do: {:ok, nil}
        end
      end
    end

    test "when the container module has only the before hook defined" do
      assert_raise ContainerError, ~r/and not/i, fn ->
        defmodule BeforeOnlyContainer do
          @moduledoc false
          use Reactor.Container

          def before_steps(_container_name, _steps), do: {:ok, nil}
        end
      end
    end

    test "when the container module has only the after hook defined" do
      assert_raise ContainerError, ~r/and not/i, fn ->
        defmodule AfterOnlyContainer do
          @moduledoc false
          use Reactor.Container

          def after_steps(_container_name, _results), do: {:ok, nil}
        end
      end
    end

    test "when the container module has just the around hook defined" do
      defmodule AroundOnlyContainer do
        @moduledoc false
        use Reactor.Container

        def around_steps(_container_name, _steps, _callback), do: {:ok, nil}
      end
    end

    test "when the container module has just the before and after hooks defined" do
      defmodule BeforeAndAfterOnlyContainer do
        @moduledoc false
        use Reactor.Container

        def before_steps(_container_name, _steps), do: {:ok, nil}
        def after_steps(_container_name, _results), do: {:ok, nil}
      end
    end
  end
end
