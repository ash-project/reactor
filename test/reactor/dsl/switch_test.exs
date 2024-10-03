defmodule Reactor.Dsl.SwitchTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Noop do
    @moduledoc false
    use Reactor.Step

    def run(_, context, _), do: {:ok, context.current_step.name}
  end

  defmodule SwitchReactor do
    @moduledoc false
    use Reactor

    input :value

    switch :is_truthy? do
      on input(:value)

      matches? &(&1 in [nil, false]) do
        step :falsy, Noop

        return :falsy
      end

      default do
        step :truthy, Noop

        return :truthy
      end
    end

    return :is_truthy?
  end

  defmodule SwitchNoDefaultReactor do
    @moduledoc false
    use Reactor

    input :value

    switch :is_nil? do
      on input(:value)

      matches? &is_nil/1 do
        step :falsy, Noop
      end
    end
  end

  test "when provided a falsy value it works" do
    assert {:ok, :falsy} = Reactor.run(SwitchReactor, value: nil)
  end

  test "when provided a truthy value it works" do
    assert {:ok, :truthy} = Reactor.run(SwitchReactor, value: :marty)
  end

  test "it does not require a default" do
    assert {:ok, nil} = Reactor.run(SwitchNoDefaultReactor, value: nil)
  end
end
