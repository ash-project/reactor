defmodule Reactor.Dsl.ContainerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "it compiles" do
    defmodule MyContainer do
      use Reactor.Container

      def before(container_name, arguments, steps) do
        {:ok, %{some: :context}}
      end
    end

    defmodule ContainerReactor do
      @moduledoc false
      use Reactor

      container :example, MyContainer do
        step :a, Example.Step.Greeter
        step :b, Example.Step.Greeter
      end
    end
  end
end
