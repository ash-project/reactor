defmodule Reactor.Executor.CompensationTest do
  use ExUnit.Case, async: true

  alias Reactor.Error.Invalid.RunStepError

  defmodule EventMiddleware do
    use Reactor.Middleware

    @moduledoc false
    def event(event, _step, context) do
      Agent.update(context.event_agent, fn events ->
        [append_elem(event, context.current_try) | events]
      end)

      :ok
    end

    defp append_elem(event, elem) when is_tuple(event) do
      event
      |> Tuple.to_list()
      |> Kernel.++([elem])
      |> List.to_tuple()
    end

    defp append_elem(event, _), do: event
  end

  def run(reactor, args, opts \\ []) do
    {:ok, pid} = Agent.start_link(fn -> [] end)

    reactor.reactor()
    |> Reactor.Builder.ensure_middleware!(EventMiddleware)
    |> Reactor.run(args, %{event_agent: pid}, opts)

    Agent.get(pid, fn events -> Enum.reverse(events) end)
  end

  defmodule CompensateReactor do
    @moduledoc false
    use Reactor

    input :compensation_result

    step :fail do
      argument :compensation_result, input(:compensation_result)
      max_retries 3

      run fn _, %{current_try: current_try} ->
        if current_try > 1 do
          {:ok, :done}
        else
          {:error, :fail}
        end
      end

      compensate fn _, arguments, _ ->
        arguments.compensation_result
      end
    end
  end

  test "increments current_try" do
    assert [
             {:run_start, _, 0},
             {:run_error, %RunStepError{error: :fail}, 0},
             {:compensate_start, %RunStepError{error: :fail}, 0},
             :compensate_retry,
             # Current behavior (current_try does not immediately increment).
             # Uncomment to make the test pass:
            #  {:run_start, _, 0},
            #  {:run_error, %RunStepError{error: :fail}, 0},
            #  {:compensate_start, %RunStepError{error: :fail}, 0},
            #  :compensate_retry,
             {:run_start, _, 1},
             {:run_error, %RunStepError{error: :fail}, 1},
             {:compensate_start, %RunStepError{error: :fail}, 1},
             :compensate_retry,
             {:run_start, _, 2},
             {:run_complete, :done, 2}
           ] =
             run(CompensateReactor, %{compensation_result: :retry}, async?: false)
  end
end
