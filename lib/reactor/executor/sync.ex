defmodule Reactor.Executor.Sync do
  @moduledoc """
  Handle the synchronous execution of a single step, along with any mutations to
  the reactor or execution state.
  """

  alias Reactor.{Error, Executor, Step}

  @doc """
  Try and run a step synchronously.
  """
  @spec run(Reactor.t(), Executor.State.t(), Step.t() | nil) ::
          {:continue | :recurse | :halt | :undo, Reactor.t(), Executor.State.t()}
  def run(reactor, state, nil), do: {:continue, reactor, state}

  def run(reactor, state, step) do
    case Executor.StepRunner.run(reactor, state, step, state.concurrency_key) do
      :retry ->
        state = increment_retries(state, step)

        if Map.get(state.retries, step.ref) >= step.max_retries do
          reactor = drop_from_plan(reactor, step)

          error =
            Error.RetriesExceededError.exception(
              step: step,
              retry_count: Map.get(state.retries, step.ref)
            )

          {:undo, reactor, %{state | errors: [error | state.errors]}}
        else
          {:recurse, reactor, state}
        end

      {:retry, reason} ->
        state = increment_retries(state, step)

        if Map.get(state.retries, step.ref) >= step.max_retries do
          reactor = drop_from_plan(reactor, step)
          {:undo, reactor, %{state | errors: [reason | state.errors]}}
        else
          {:recurse, reactor, state}
        end

      {:ok, value, new_steps} ->
        reactor =
          reactor
          |> maybe_store_undo(step, value)
          |> maybe_store_intermediate_result(step, value)
          |> drop_from_plan(step)
          |> append_steps(new_steps)

        {:recurse, reactor, state}

      {:error, reason} ->
        state = %{state | errors: [reason | state.errors]}
        reactor = drop_from_plan(reactor, step)
        {:undo, reactor, state}

      {:halt, value} ->
        reactor =
          reactor
          |> drop_from_plan(step)
          |> store_intermediate_result(step, value)

        {:halt, reactor, state}
    end
  end

  defp increment_retries(state, step) do
    %{state | retries: Map.update(state.retries, step.ref, 0, &(&1 + 1))}
  end

  defp drop_from_plan(reactor, step) do
    %{reactor | plan: Graph.delete_vertex(reactor.plan, step)}
  end

  defp maybe_store_undo(reactor, step, value) do
    if Step.can?(step, :undo) do
      %{reactor | undo: [{step, value} | reactor.undo]}
    else
      reactor
    end
  end

  defp maybe_store_intermediate_result(reactor, step, value) do
    cond do
      Graph.out_degree(reactor.plan, step) > 0 ->
        store_intermediate_result(reactor, step, value)

      reactor.return == step.name ->
        store_intermediate_result(reactor, step, value)

      true ->
        reactor
    end
  end

  defp store_intermediate_result(reactor, step, value),
    do: %{reactor | intermediate_results: Map.put(reactor.intermediate_results, step.name, value)}

  defp append_steps(reactor, steps), do: %{reactor | steps: Enum.concat(steps, reactor.steps)}
end
