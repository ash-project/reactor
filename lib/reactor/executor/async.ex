defmodule Reactor.Executor.Async do
  @moduledoc """
  Handle the asynchronous execution of a batch of steps, along with any
  mutations to the reactor or execution state.
  """
  alias Reactor.Executor.ConcurrencyTracker
  alias Reactor.{Error, Executor, Step}
  require Logger

  @doc """
  Start as many of the provided steps as possible.

  Takes into account he maximum concurrency and available work slots.
  """
  @spec start_steps(Reactor.t(), Executor.State.t(), [Step.t()], Supervisor.supervisor()) ::
          {:continue | :recurse, Reactor.t(), Executor.State.t()} | {:error, any}
  def start_steps(
        reactor,
        state,
        steps,
        supervisor \\ {:via, PartitionSupervisor, {Reactor.TaskSupervisor, self()}}
      )

  def start_steps(reactor, state, [], _supervisor), do: {:continue, reactor, state}

  def start_steps(reactor, state, steps, supervisor) do
    available_steps = length(steps)

    locked_concurrency =
      acquire_concurrency_resource_from_pool(state.concurrency_key, available_steps)

    started =
      steps
      |> Enum.take(locked_concurrency)
      |> Enum.reduce_while(%{}, fn step, started ->
        case start_task_for_step(reactor, state, step, supervisor, state.concurrency_key) do
          {:ok, task} -> {:cont, Map.put(started, task, step)}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    if map_size(started) > 0 do
      reactor = add_task_edges(reactor, started)
      state = %{state | current_tasks: Map.merge(state.current_tasks, started)}
      {:recurse, reactor, state}
    else
      {:continue, reactor, state}
    end
  end

  defp start_task_for_step(reactor, state, step, supervisor, pool_key) do
    {:ok,
     Task.Supervisor.async_nolink(
       supervisor,
       Executor.StepRunner,
       :run,
       [reactor, state, step, pool_key]
     )}
  rescue
    error -> {:error, error}
  end

  @doc """
  Check to see if any steps are completed, and if so handle them.
  """
  @spec handle_completed_steps(Reactor.t(), Executor.State.t()) ::
          {:recurse | :continue | :undo | :halt, Reactor.t(), Executor.State.t()}
  def handle_completed_steps(reactor, state) do
    completed_task_results = get_normalised_task_results(state.current_tasks, 100)

    reactor
    |> delete_vertices(Map.keys(completed_task_results))
    |> handle_completed_steps(state, completed_task_results)
  end

  defp handle_completed_steps(reactor, state, completed_task_results)
       when map_size(completed_task_results) == 0,
       do: {:continue, reactor, state}

  defp handle_completed_steps(reactor, state, completed_task_results) do
    release_concurrency_resources_to_pool(state.concurrency_key, map_size(completed_task_results))

    new_current_tasks = Map.drop(state.current_tasks, Map.keys(completed_task_results))

    completed_step_results =
      completed_task_results
      |> Map.values()
      |> Map.new()

    retry_steps =
      completed_step_results
      |> Enum.filter(fn
        {_, :retry} -> true
        {_, {:retry, _}} -> true
        _ -> false
      end)
      |> Enum.map(&elem(&1, 0))

    steps_to_remove =
      completed_step_results
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(retry_steps))
      |> Enum.to_list()

    steps_to_append =
      completed_step_results
      |> Map.values()
      |> Enum.flat_map(fn
        {:ok, _, steps} -> steps
        _ -> []
      end)

    reactor =
      reactor
      |> store_successful_results_in_the_undo_stack(completed_step_results)
      |> store_intermediate_results(completed_step_results)
      |> delete_vertices(steps_to_remove)
      |> append_steps(steps_to_append)

    state =
      state
      |> increment_retry_counts(retry_steps)
      |> collect_errors(completed_step_results)

    status =
      completed_task_results
      |> Enum.find_value(:ok, fn
        {_task, {_step, {:halt, _}}} ->
          :halt

        {_task, {_step, {:error, _}}} ->
          :undo

        {_task, {step, :retry}} ->
          if Map.get(state.retries, step.ref) >= step.max_retries,
            do: :undo

        _ ->
          nil
      end)

    state = %{state | current_tasks: new_current_tasks}

    case status do
      :ok ->
        {:recurse, reactor, state}

      :undo ->
        {reactor, state} = collect_remaining_tasks_for_shutdown(reactor, state)
        {:undo, reactor, state}

      :halt ->
        {reactor, state} = collect_remaining_tasks_for_shutdown(reactor, state)
        {:halt, reactor, state}
    end
  end

  defp get_normalised_task_results(current_tasks, timeout) do
    current_tasks
    |> Map.keys()
    |> Task.yield_many(timeout)
    |> Stream.reject(&is_nil(elem(&1, 1)))
    |> Stream.map(fn
      {task, {:ok, {:error, reason}}} ->
        {task, {:error, reason}}

      {task, {:ok, {:halt, reason}}} ->
        {task, {:halt, reason}}

      {task, {:ok, :retry}} ->
        {task, :retry}

      {task, {:ok, {:retry, reason}}} ->
        {task, {:retry, reason}}

      {task, {:ok, {:ok, value, steps}}} when is_list(steps) ->
        {task, {:ok, value, steps}}

      {task, {:exit, reason}} ->
        {task, {:error, reason}}
    end)
    |> Map.new(fn {task, result} ->
      {task, {Map.fetch!(current_tasks, task), result}}
    end)
  end

  defp store_successful_results_in_the_undo_stack(reactor, completed_step_results)
       when map_size(completed_step_results) == 0,
       do: reactor

  defp store_successful_results_in_the_undo_stack(reactor, completed_step_results) do
    undoable_successful_results =
      completed_step_results
      |> Enum.filter(fn
        {step, {:ok, _, _}} -> Step.can?(step, :undo)
        {step, {:halt, _}} -> Step.can?(step, :undo)
        _ -> false
      end)
      |> Map.new(fn
        {step, {:ok, value, _}} -> {step, value}
        {step, {:halt, value}} -> {step, value}
      end)

    %{reactor | undo: Enum.concat(reactor.undo, undoable_successful_results)}
  end

  defp store_intermediate_results(reactor, completed_step_results)
       when map_size(completed_step_results) == 0,
       do: reactor

  defp store_intermediate_results(reactor, completed_step_results) do
    intermediate_results =
      completed_step_results
      |> Enum.filter(fn
        {step, {:ok, _, []}} ->
          Graph.out_degree(reactor.plan, step) > 0 || reactor.return == step.name

        {step, {:ok, _, new_steps}} ->
          any_new_step_depends_on_this_step?(step, new_steps)

        {_step, {:halt, _}} ->
          true

        _ ->
          false
      end)
      |> Map.new(fn
        {step, {:ok, value, _}} -> {step.name, value}
        {step, {:halt, value}} -> {step.name, value}
      end)

    %{
      reactor
      | intermediate_results: Map.merge(reactor.intermediate_results, intermediate_results)
    }
  end

  defp append_steps(reactor, steps), do: %{reactor | steps: Enum.concat(steps, reactor.steps)}

  defp any_new_step_depends_on_this_step?(_step, []), do: false

  defp any_new_step_depends_on_this_step?(step, new_steps) do
    Enum.any?(new_steps, fn new_step ->
      Enum.any?(new_step.arguments, fn argument ->
        is_struct(argument.source, Reactor.Template.Result) && argument.source.name == step.name
      end)
    end)
  end

  defp increment_retry_counts(state, retry_steps) do
    retries =
      retry_steps
      |> Enum.reduce(state.retries, fn step, retries ->
        Map.update(retries, step.ref, 1, &(&1 + 1))
      end)

    %{state | retries: retries}
  end

  defp collect_errors(state, completed_step_results) do
    errors =
      completed_step_results
      |> Enum.filter(fn
        {_step, {:error, _}} ->
          true

        {step, {:retry, _}} ->
          Map.get(state.retries, step.ref) >= step.max_retries

        {step, :retry} ->
          Map.get(state.retries, step.ref) >= step.max_retries

        _ ->
          false
      end)
      |> Enum.map(fn
        {_step, {_, reason}} ->
          reason

        {step, :retry} ->
          Error.RetriesExceededError.exception(
            step: step,
            retry_count: Map.get(state.retries, step.ref)
          )
      end)
      |> Enum.concat(state.errors)

    %{state | errors: errors}
  end

  @doc """
  When the Reactor needs to shut down for any reason, we need to await all the
  currently running asynchronous steps and delete any task vertices.
  """
  @spec collect_remaining_tasks_for_shutdown(Reactor.t(), Executor.State.t()) ::
          {Reactor.t(), Executor.State.t()}
  def collect_remaining_tasks_for_shutdown(reactor, state)
      when map_size(state.current_tasks) == 0 do
    {delete_all_task_vertices(reactor), state}
  end

  def collect_remaining_tasks_for_shutdown(reactor, state) do
    remaining_task_results = get_normalised_task_results(state.current_tasks, state.halt_timeout)

    release_concurrency_resources_to_pool(state.concurrency_key, map_size(remaining_task_results))

    remaining_step_results =
      remaining_task_results
      |> Map.values()
      |> Map.new()

    reactor =
      reactor
      |> store_successful_results_in_the_undo_stack(remaining_step_results)
      |> store_intermediate_results(remaining_step_results)

    unfinished_tasks =
      state.current_tasks
      |> Map.delete(Map.keys(remaining_task_results))

    unfinished_task_count = map_size(unfinished_tasks)

    if unfinished_task_count > 0 do
      Logger.warning(fn ->
        unfinished_steps =
          unfinished_tasks
          |> Map.values()
          |> Enum.map_join("\n  * ", &inspect/1)

        """
        Waited #{state.halt_timeout}ms for async steps to complete, however #{unfinished_task_count} are still running and will be abandoned and cannot be undone.

          * #{unfinished_steps}
        """
      end)

      unfinished_tasks
      |> Map.keys()
      |> Enum.each(&Task.ignore/1)
    end

    {delete_all_task_vertices(reactor), %{state | current_tasks: %{}}}
  end

  defp add_task_edges(reactor, started_tasks) do
    plan =
      Enum.reduce(started_tasks, reactor.plan, fn {task, step}, plan ->
        Graph.add_edge(plan, task, step, label: :executing)
      end)

    %{reactor | plan: plan}
  end

  defp delete_vertices(reactor, []), do: reactor

  defp delete_vertices(reactor, completed_tasks),
    do: %{reactor | plan: Graph.delete_vertices(reactor.plan, completed_tasks)}

  defp delete_all_task_vertices(reactor) do
    task_vertices =
      reactor.plan
      |> Graph.vertices()
      |> Enum.filter(&is_struct(&1, Task))

    delete_vertices(reactor, task_vertices)
  end

  defp release_concurrency_resources_to_pool(pool_key, how_many) do
    ConcurrencyTracker.release(pool_key, how_many)
  end

  defp acquire_concurrency_resource_from_pool(pool_key, requested) do
    {:ok, actual} = ConcurrencyTracker.acquire(pool_key, requested)
    actual
  end
end
