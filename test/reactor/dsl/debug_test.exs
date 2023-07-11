defmodule Reactor.Dsl.DebugTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule DebugReactor do
    @moduledoc false
    use Reactor

    input :value

    step :squared do
      argument :value, input(:value)

      run fn %{value: value} -> {:ok, value * value} end
    end

    debug :debug do
      argument :squared, result(:squared)
    end
  end

  test "it works" do
    log =
      capture_log(fn ->
        assert {:ok, _} = Reactor.run(DebugReactor, %{value: 13})
      end)

    assert log =~ ~r/\[debug\] # debug information for step `:debug`/i
    assert log =~ "%{squared: 169}"
    assert log =~ "concurrency_key:"
  end
end
