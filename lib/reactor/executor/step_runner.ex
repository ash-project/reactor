defmodule Reactor.Executor.StepRunner do
  @moduledoc """
  Run an individual step, including compensation if possible.
  """
  alias Reactor.{Executor.ConcurrencyTracker, Executor.Hooks, Executor.State, Step}
  import Reactor.Utils
  import Reactor.Argument, only: :macros
  require Logger

  # In the future this could be moved into a step property.
  @max_undo_count 5

  @doc """
  Collect the arguments and and run a step, with compensation if required.
  """
  @spec run(Reactor.t(), State.t(), Step.t(), ConcurrencyTracker.pool_key()) ::
          {:ok, any, [Step.t()]} | :retry | {:retry, any} | {:error | :halt, any}
  def run(reactor, state, step, concurrency_key) do
    with {:ok, arguments} <- get_step_arguments(reactor, step),
         {:ok, context} <- build_context(reactor, state, step, concurrency_key),
         {:ok, arguments} <- maybe_replace_arguments(arguments, context) do
      metadata = %{
        current_step: step,
        pid: self(),
        reactor: reactor,
        concurrency_key: concurrency_key
      }

      metadata_stack = Process.get(:__reactor__, [])
      Process.put(:__reactor__, [metadata | metadata_stack])
      result = do_run(reactor, step, arguments, context)
      Process.put(:__reactor__, metadata_stack)
      result
    end
  end

  @doc """
  Run a step inside a task.

  This is a simple wrapper around `run/4` except that it emits more events.
  """
  @spec run_async(Reactor.t(), State.t(), Step.t(), ConcurrencyTracker.pool_key(), map) ::
          {:ok, any, [Step.t()]} | :retry | {:retry, any} | {:error | :halt, any}
  def run_async(reactor, state, step, concurrency_key, process_contexts) do
    Hooks.set_process_contexts(process_contexts)
    Hooks.event(reactor, {:process_start, self()}, step, reactor.context)

    run(reactor, state, step, concurrency_key)
  after
    Hooks.event(reactor, {:process_terminate, self()}, step, reactor.context)
  end

  @doc """
  Undo a step if possible.
  """
  @spec undo(Reactor.t(), State.t(), Step.t(), any, ConcurrencyTracker.pool_key()) ::
          :ok | {:error, any}
  def undo(reactor, state, step, value, concurrency_key) do
    with {:ok, arguments} <- get_step_arguments(reactor, step),
         {:ok, context} <- build_context(reactor, state, step, concurrency_key),
         {:ok, arguments} <- maybe_replace_arguments(arguments, context) do
      Hooks.event(reactor, :undo_start, step, context)

      do_undo(reactor, value, step, arguments, context, 0)
    end
  end

  defp do_undo(reactor, _value, step, _arguments, context, undo_count)
       when undo_count == @max_undo_count do
    reason = "`undo/4` retried #{@max_undo_count} times on step `#{inspect(step.name)}`."

    Hooks.event(reactor, {:undo_error, reason}, step, context)

    {:error, reason}
  end

  defp do_undo(reactor, value, step, arguments, context, undo_count) do
    case Step.undo(step, value, arguments, context) do
      :ok ->
        Hooks.event(reactor, :undo_complete, step, context)

        :ok

      :retry ->
        Hooks.event(reactor, :undo_retry, step, context)
        do_undo(reactor, value, step, arguments, context, undo_count + 1)

      {:retry, reason} ->
        Hooks.event(reactor, {:undo_retry, reason}, step, context)
        do_undo(reactor, value, step, arguments, context, undo_count + 1)

      {:error, reason} ->
        Hooks.event(reactor, {:undo_error, reason}, step, context)
        {:error, reason}
    end
  end

  defp do_run(reactor, step, arguments, context) do
    Hooks.event(reactor, {:run_start, arguments}, step, context)

    step
    |> Step.run(arguments, context)
    |> handle_run_result(reactor, step, arguments, context)
  rescue
    reason ->
      Hooks.event(reactor, {:run_error, reason}, step, context)

      maybe_compensate(reactor, step, reason, arguments, context)
  end

  defp handle_run_result({:ok, value}, reactor, step, _arguments, context) do
    Hooks.event(reactor, {:run_complete, value}, step, context)

    {:ok, value, []}
  end

  defp handle_run_result({:ok, value, steps}, reactor, step, _arguments, context)
       when is_list(steps) do
    Hooks.event(reactor, {:run_complete, value}, step, context)

    {:ok, value, steps}
  end

  defp handle_run_result({:retry, reason}, reactor, step, _arguments, context) do
    Hooks.event(reactor, {:run_retry, reason}, step, context)

    {:retry, reason}
  end

  defp handle_run_result(:retry, reactor, step, _arguments, context) do
    Hooks.event(reactor, :run_retry, step, context)

    :retry
  end

  defp handle_run_result({:error, reason}, reactor, step, arguments, context) do
    Hooks.event(reactor, {:run_error, reason}, step, context)

    maybe_compensate(reactor, step, reason, arguments, context)
  end

  defp handle_run_result({:halt, value}, reactor, step, _arguments, context) do
    Hooks.event(reactor, {:run_halt, value}, step, context)

    {:halt, value}
  end

  defp maybe_compensate(reactor, step, reason, arguments, context) do
    if Step.can?(step, :compensate) do
      compensate(reactor, step, reason, arguments, context)
    else
      {:error, reason}
    end
  end

  defp compensate(reactor, step, reason, arguments, context) do
    Hooks.event(reactor, {:compensate_start, reason}, step, context)

    step
    |> Step.compensate(reason, arguments, context)
    |> handle_compensate_result(reactor, step, context, reason)
  rescue
    error ->
      Hooks.event(reactor, {:compensate_error, reason}, step, context)

      Logger.error(fn ->
        "Warning: step `#{inspect(step.name)}` `compensate/4` raised an error:\n" <>
          Exception.format(:error, error, __STACKTRACE__)
      end)

      {:error, reason}
  end

  defp handle_compensate_result({:continue, value}, reactor, step, context, _) do
    Hooks.event(reactor, {:compensate_continue, value}, step, context)

    {:ok, value, []}
  end

  defp handle_compensate_result({:retry, reason}, reactor, step, context, _) do
    Hooks.event(reactor, {:compensate_retry, reason}, step, context)

    {:retry, reason}
  end

  defp handle_compensate_result(:retry, reactor, step, context, reason) do
    Hooks.event(reactor, :compensate_retry, step, context)

    {:retry, reason}
  end

  defp handle_compensate_result({:error, reason}, reactor, step, context, _) do
    Hooks.event(reactor, {:compensate_error, reason}, step, context)

    {:error, reason}
  end

  defp handle_compensate_result(:ok, reactor, step, context, reason) do
    Hooks.event(reactor, :compensate_complete, step, context)

    {:error, reason}
  end

  defp get_step_arguments(reactor, step) do
    reduce_while_ok(step.arguments, %{}, fn
      argument, arguments when argument.name == :_ ->
        {:ok, arguments}

      argument, arguments ->
        with {:ok, value} <- fetch_argument(reactor, step, argument),
             {:ok, value} <- subpath_argument(value, argument) do
          {:ok, Map.put(arguments, argument.name, value)}
        end
    end)
  end

  defp fetch_argument(reactor, step, argument) when is_from_input(argument) do
    with :error <- Map.fetch(reactor.context.private.inputs, argument.source.name) do
      {:error,
       "Step `#{inspect(step.name)}` argument `#{inspect(argument.name)}` relies on missing input `#{argument.source.name}`"}
    end
  end

  defp fetch_argument(reactor, step, argument) when is_from_result(argument) do
    with :error <- Map.fetch(reactor.intermediate_results, argument.source.name) do
      {:error, "Step `#{inspect(step.name)}` argument `#{inspect(argument.name)}` is missing"}
    end
  end

  defp fetch_argument(_reactor, _step, argument) when is_from_value(argument) do
    {:ok, argument.source.value}
  end

  defp subpath_argument(value, argument) when has_sub_path(argument),
    do: perform_argument_subpath(value, argument.name, argument.source.sub_path, [])

  defp subpath_argument(value, _argument), do: {:ok, value}

  defp perform_argument_subpath(value, _, [], _), do: {:ok, value}

  defp perform_argument_subpath(value, name, remaining, done) when is_struct(value),
    do: value |> Map.from_struct() |> perform_argument_subpath(name, remaining, done)

  defp perform_argument_subpath(value, name, [head | tail], []) do
    case access_fetch_with_rescue(value, head) do
      {:ok, value} ->
        perform_argument_subpath(value, name, tail, [head])

      :error ->
        {:error,
         "Unable to resolve subpath for argument `#{inspect(name)}` at key `[#{inspect(head)}]`"}
    end
  end

  defp perform_argument_subpath(value, name, [head | tail], done) do
    case access_fetch_with_rescue(value, head) do
      {:ok, value} ->
        perform_argument_subpath(value, name, tail, [head])

      :error ->
        path = Enum.reverse([head | done])

        {:error,
         "Unable to resolve subpath for argument `#{inspect(name)}` at key `#{inspect(path)}`"}
    end
  end

  defp access_fetch_with_rescue(container, key) do
    Access.fetch(container, key)
  rescue
    FunctionClauseError -> :error
  end

  defp build_context(reactor, state, step, concurrency_key) do
    current_try =
      state
      |> Map.get(:retries, %{})
      |> Map.get(step.ref, 0)

    retries_remaining =
      step
      |> Map.get(:max_retries)
      |> case do
        :infinity -> :infinity
        max when is_integer(max) and max >= 0 -> max - current_try
      end

    context =
      step.context
      |> deep_merge(reactor.context)
      |> Map.merge(%{
        current_step: step,
        concurrency_key: concurrency_key,
        current_try: current_try,
        retries_remaining: retries_remaining
      })
      |> Map.put(:current_step, step)
      |> Map.put(:concurrency_key, concurrency_key)

    {:ok, context}
  end

  defp maybe_replace_arguments(arguments, context) when is_nil(context.private.replace_arguments),
    do: {:ok, arguments}

  defp maybe_replace_arguments(arguments, context)
       when is_map_key(arguments, context.private.replace_arguments),
       do: {:ok, Map.get(arguments, context.private.replace_arguments)}

  defp maybe_replace_arguments(arguments, _context), do: {:ok, arguments}
end
