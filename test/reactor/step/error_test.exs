defmodule Reactor.Step.ErrorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule ErrorStep do
    @moduledoc false
    use Reactor.Step

    @impl true
    def run(_argument, _context, _options) do
      raise "This step always returns an error"
    end
  end

  defmodule ErrorReactor do
    @moduledoc false
    use Reactor

    step :named_step, ErrorStep
  end

  test "it has stacktrace available in error" do
    {:error, %{errors: [%{stacktrace: stacktrace}]}} = Reactor.run(ErrorReactor, %{})
    assert stacktrace.stacktrace |> Enum.any?(&match?({ErrorStep, :run, 3, _}, &1))
  end
end
