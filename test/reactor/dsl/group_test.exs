defmodule Reactor.Dsl.GroupTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Noop do
    @moduledoc false
    use Reactor.Step

    def run(_, context, _), do: {:ok, context.current_step.name}
  end

  defmodule GroupReactor do
    @moduledoc false

    use Reactor

    group :group do
      before_all &__MODULE__.do_before/3
      after_all &__MODULE__.do_after/1

      step :a, Noop
      step :b, Noop
    end

    def do_before(arguments, context, steps) do
      steps = Enum.filter(steps, &(&1.name == :b))
      {:ok, arguments, context, steps}
    end

    def do_after(results) do
      {:ok, results}
    end
  end

  test "it works" do
    assert {:ok, result} = Reactor.run(GroupReactor)
    assert result == %{b: :b}
  end
end
