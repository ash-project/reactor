defmodule Reactor.Executor do
  @moduledoc """
  The Reactor executor.

  The executor handles the main loop of running a Reactor.

  The algorithm is somewhat confusing, so here it is in pseudocode:

  1. Find any async tasks (from a previous loop) which are completed. Either
     recurse or continue if none are found.
  2. Find any async steps in the plan which are ready to run (they have no
     in-edges in the graph) and start as many as possible (given the constraints
     of `max_concurrency` and the state of the concurrency pool).  Either start
     over, or continue if none are found.
  3. Find a single synchronous step which is ready to run and execute it. If
     there was one then recurse, otherwise continue.
  4. Check if there are no more steps left in the plan (there are zero
     vertices).  If so, collect the return value and exit, otherwise recurse.

  Whenever a step is run, whether run synchronously or asynchronously, the
  following happens:

  1. When the step is successful:
    a. If the step is undoable (ie `Step.can?(module, :undo)?` returns `true`)
       then the step and the result are stored in the Reactor's undo stack.
    b. If the result is depended upon by another step (the graph has out-edges
       for the step) _or_ the step is asking the reactor to halt then the
       result is stored in the Reactor's intermediate results.
    c. The step is removed from the graph (along with it's out-edges, freeing
       up it's dependents to run).
  2. When the step is unsuccessful (returns an error tuple or raises):
    a. If the step can be compensated then compensation is attempted up to five
       times before giving up.
    b. The reactor iterates it's undo stack calling undo on each step.
  3. When a step or compensation asks for a retry then the step is placed back
     in the graph to be run again next iteration.
  """
  alias Reactor.Executor.ConcurrencyTracker
  alias Reactor.{Executor, Planner, Step}

  @doc """
  Run a reactor.

  Provided a Reactor which has been planned and the correct inputs, then run
  the Reactor until completion, halting or failure.

  You probably shouldn't call this directly, but use `Reactor.run/4` instead.
  """
  @spec run(Reactor.t(), Reactor.inputs(), Reactor.context(), Reactor.options()) ::
          {:ok, any} | {:halted, Reactor.t()} | {:error, any}
  def run(reactor, inputs \\ %{}, context \\ %{}, options \\ [])

  def run(reactor, _inputs, _context, _options) when is_nil(reactor.return),
    do: {:error, ArgumentError.exception("`reactor` has no return value")}

  def run(reactor, inputs, context, options) when reactor.state in ~w[pending halted]a do
    case Executor.Init.init(reactor, inputs, context, options) do
      {:ok, reactor, state} -> execute(reactor, state)
      {:error, reason} -> {:error, reason}
    end
  end

  def run(_reactor, _inputs, _context, _options),
    do: {:error, ArgumentError.exception("`reactor` is not in `pending` or `halted` state")}

  defp execute(reactor, state) when state.max_iterations == 0 do
    {reactor, _status} = Executor.Async.collect_remaining_tasks_for_shutdown(reactor, state)
    maybe_release_pool(state)
    {:halted, %{reactor | state: :halted}}
  end

  defp execute(reactor, state) do
    with {:continue, reactor, state} <- maybe_timeout(reactor, state),
         {:continue, reactor, state} <- handle_unplanned_steps(reactor, state),
         {:continue, reactor, state} <- handle_completed_async_steps(reactor, state),
         {:continue, ready_steps} <- find_ready_steps(reactor),
         {:continue, reactor, state} <- start_ready_async_steps(reactor, state, ready_steps),
         {:continue, reactor, state} <- run_ready_sync_step(reactor, state, ready_steps),
         {:continue, reactor} <- all_done(reactor) do
      execute(reactor, subtract_iteration(state))
    else
      {:recurse, reactor, state} ->
        execute(reactor, subtract_iteration(state))

      {:undo, reactor, state} ->
        handle_undo(reactor, state)

      {:halt, reactor, _state} ->
        maybe_release_pool(state)
        {:halted, %{reactor | state: :halted}}

      {:ok, result} ->
        maybe_release_pool(state)
        {:ok, result}

      {:error, reason} ->
        maybe_release_pool(state)
        {:error, reason}
    end
  end

  defp maybe_timeout(reactor, state) when state.timeout == :infinity,
    do: {:continue, reactor, state}

  defp maybe_timeout(reactor, state) do
    if DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond) >= state.timeout do
      {reactor, _status} = Executor.Async.collect_remaining_tasks_for_shutdown(reactor, state)
      {:halt, reactor, state}
    else
      {:continue, reactor, state}
    end
  end

  defp handle_unplanned_steps(reactor, state) when reactor.steps == [],
    do: {:continue, reactor, state}

  defp handle_unplanned_steps(reactor, state) do
    case Planner.plan(reactor) do
      {:ok, reactor} -> {:recurse, reactor, state}
      {:error, reason} -> {:undo, reactor, %{state | errors: [reason | state.errors]}}
    end
  end

  defp handle_completed_async_steps(reactor, state) when state.async? == false,
    do: {:continue, reactor, state}

  defp handle_completed_async_steps(reactor, state),
    do: Executor.Async.handle_completed_steps(reactor, state)

  defp start_ready_async_steps(reactor, state, _) when state.async? == false,
    do: {:continue, reactor, state}

  defp start_ready_async_steps(reactor, state, []), do: {:continue, reactor, state}

  defp start_ready_async_steps(reactor, state, _steps)
       when map_size(state.current_tasks) == state.max_concurrency,
       do: {:continue, reactor, state}

  defp start_ready_async_steps(reactor, state, steps) do
    steps = Enum.filter(steps, &(&1.async? == true))

    Executor.Async.start_steps(reactor, state, steps)
  end

  defp run_ready_sync_step(reactor, state, []), do: {:continue, reactor, state}

  defp run_ready_sync_step(reactor, state, [step | _]) when state.async? == false do
    Executor.Sync.run(reactor, state, step)
  end

  defp run_ready_sync_step(reactor, state, steps) do
    step = Enum.find(steps, &(&1.async? == false))

    Executor.Sync.run(reactor, state, step)
  end

  defp subtract_iteration(state) when state.max_iterations == :infinity, do: state

  defp subtract_iteration(state) when state.max_iterations > 0,
    do: %{state | max_iterations: state.max_iterations - 1}

  defp handle_undo(reactor, state) do
    handle_undo(%{reactor | state: :failed, undo: []}, state, Enum.reverse(reactor.undo))
  end

  defp handle_undo(_reactor, state, []), do: {:error, state.errors}

  defp handle_undo(reactor, state, [{step, value} | tail]) do
    case Executor.StepRunner.undo(reactor, step, value, state.concurrency_key) do
      :ok -> handle_undo(reactor, state, tail)
      {:error, reason} -> handle_undo(reactor, %{state | errors: [reason | state.errors]}, tail)
    end
  end

  defp all_done(reactor) do
    with 0 <- Graph.num_vertices(reactor.plan),
         {:ok, value} <- Map.fetch(reactor.intermediate_results, reactor.return) do
      {:ok, value}
    else
      :error -> {:error, "Unable to find result for `#{inspect(reactor.return)}` step"}
      n when is_integer(n) -> {:continue, reactor}
    end
  end

  defp find_ready_steps(reactor) do
    steps =
      reactor.plan
      |> Graph.vertices()
      |> Enum.filter(fn
        step when is_struct(step, Step) -> Graph.in_degree(reactor.plan, step) == 0
        _ -> false
      end)

    {:continue, steps}
  end

  defp maybe_release_pool(state) when state.pool_owner == true do
    ConcurrencyTracker.release_pool(state.concurrency_key)
  end

  defp maybe_release_pool(_), do: :ok
end
