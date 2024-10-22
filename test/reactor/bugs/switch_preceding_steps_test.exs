defmodule Reactor.Bugs.SwitchPrecedingStepsTest do
  @moduledoc false
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  defmodule MooStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(_args, _context, _opts) do
      Logger.warning("MOO")
      {:ok, :moo}
    end
  end

  defmodule BooStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(args, _context, _opts) do
      Logger.warning("BOO")
      {:ok, !args.value}
    end
  end

  defmodule TruthyStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(_args, _context, _opts) do
      Logger.warning("TRUTHY")
      {:ok, :truthy}
    end
  end

  defmodule FalsyStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(_args, _context, _opts) do
      Logger.warning("FALSY")
      {:ok, :falsy}
    end
  end

  defmodule BugReactor do
    @moduledoc false
    use Reactor

    input :value

    step :moo, MooStep

    step :boo, BooStep do
      argument :value, input(:value)
    end

    switch :is_truthy? do
      on result(:boo)

      matches? &(&1 in [nil, false]) do
        step :falsy, FalsyStep
      end

      default do
        step :truthy, TruthyStep
      end
    end
  end

  test "steps preceding a switch only get executed once" do
    logs =
      [level: :warning, format: "$message\n", colors: [enabled: false]]
      |> capture_log(fn ->
        Reactor.run(BugReactor, %{value: true})
      end)
      |> String.split(~r/\n+/)
      |> Enum.reject(&(&1 == ""))
      |> Enum.frequencies()

    assert logs["MOO"] == 1
    assert logs["BOO"] == 1
    assert logs["FALSY"] == 1
  end
end
