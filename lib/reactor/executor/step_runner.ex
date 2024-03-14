defmodule Reactor.Executor.StepRunner do
  @moduledoc """
  Run an individual step, including compensation if possible.
  """
  alias Reactor.{
    Error.Invalid.ArgumentSubpathError,
    Error.Invalid.CompensateStepError,
    Error.Invalid.MissingInputError,
    Error.Invalid.MissingResultError,
    Error.Invalid.RunStepError,
    Error.Invalid.UndoRetriesExceededError,
    Error.Invalid.UndoStepError,
    Executor.ConcurrencyTracker,
    Executor.Hooks,
    Executor.State,
    Step
  }

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
    error = UndoRetriesExceededError.exception(step: step.name, retry_count: undo_count)

    Hooks.event(reactor, {:undo_error, error}, step, context)

    {:error, error}
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
        error = UndoStepError.exception(step: step.name, error: reason)
        Hooks.event(reactor, {:undo_error, error}, step, context)
        {:error, error}
    end
  end

  defp do_run(reactor, step, arguments, context) do
    Hooks.event(reactor, {:run_start, arguments}, step, context)

    step
    |> Step.run(arguments, context)
    |> handle_run_result(reactor, step, arguments, context)
  rescue
    reason ->
      error = RunStepError.exception(step: step.name, error: reason)
      Hooks.event(reactor, {:run_error, error}, step, context)

      maybe_compensate(reactor, step, error, arguments, context)
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
    error = RunStepError.exception(step: step.name, error: reason)
    Hooks.event(reactor, {:run_error, error}, step, context)

    maybe_compensate(reactor, step, error, arguments, context)
  end

  defp handle_run_result({:halt, value}, reactor, step, _arguments, context) do
    Hooks.event(reactor, {:run_halt, value}, step, context)

    {:halt, value}
  end

  defp maybe_compensate(reactor, step, error, arguments, context) do
    if Step.can?(step, :compensate) do
      compensate(reactor, step, error, arguments, context)
    else
      {:error, error}
    end
  end

  defp compensate(reactor, step, error, arguments, context) do
    Hooks.event(reactor, {:compensate_start, error}, step, context)

    step
    |> Step.compensate(error.error, arguments, context)
    |> handle_compensate_result(reactor, step, context, error)
  rescue
    error ->
      error =
        CompensateStepError.exception(
          reactor: reactor,
          step: step,
          error: error,
          stacktrace: __STACKTRACE__
        )

      Hooks.event(reactor, {:compensate_error, error}, step, context)

      Logger.error(fn ->
        "Warning: step `#{inspect(step.name)}` `compensate/4` raised an error:\n" <>
          Exception.format(:error, error, __STACKTRACE__)
      end)

      {:error, error}
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
    error = CompensateStepError.exception(reactor: reactor, step: step, error: reason)

    Hooks.event(reactor, {:compensate_error, error}, step, context)

    {:error, error}
  end

  defp handle_compensate_result(:ok, reactor, step, context, error) do
    Hooks.event(reactor, :compensate_complete, step, context)

    {:error, error}
  end

  defp get_step_arguments(reactor, step) do
    reduce_while_ok(step.arguments, %{}, fn
      argument, arguments when argument.name == :_ ->
        {:ok, arguments}

      argument, arguments ->
        with {:ok, value} <- fetch_argument(reactor, step, argument),
             {:ok, value} <- subpath_argument(value, step, argument) do
          {:ok, Map.put(arguments, argument.name, value)}
        end
    end)
  end

  defp fetch_argument(reactor, step, argument) when is_from_input(argument) do
    with :error <- Map.fetch(reactor.context.private.inputs, argument.source.name) do
      {:error, MissingInputError.exception(reactor: reactor, step: step, argument: argument)}
    end
  end

  defp fetch_argument(reactor, step, argument) when is_from_result(argument) do
    with :error <- Map.fetch(reactor.intermediate_results, argument.source.name) do
      {:error, MissingResultError.exception(reactor: reactor, step: step, argument: argument)}
    end
  end

  defp fetch_argument(_reactor, _step, argument) when is_from_value(argument) do
    {:ok, argument.source.value}
  end

  defp subpath_argument(value, step, argument) when has_sub_path(argument),
    do: perform_argument_subpath(value, step, argument, argument.source.sub_path, [], value)

  defp subpath_argument(value, _step, _argument), do: {:ok, value}

  defp perform_argument_subpath(
         value,
         step,
         argument,
         remaining_path,
         done_path,
         intermediate_value
       )

  defp perform_argument_subpath(_value, _step, _argument, [], _, result), do: {:ok, result}

  defp perform_argument_subpath(
         value,
         step,
         argument,
         [key | remaining_path],
         done_path,
         intermediate_value
       )
       when is_map(intermediate_value) do
    case Map.fetch(intermediate_value, key) do
      {:ok, intermediate_value} ->
        perform_argument_subpath(
          value,
          step,
          argument,
          remaining_path,
          [key | done_path],
          intermediate_value
        )

      :error ->
        type = if is_struct(intermediate_value), do: "struct", else: "map"

        {:error,
         ArgumentSubpathError.exception(
           step: step,
           argument: argument,
           culprit: intermediate_value,
           culprit_path: done_path,
           culprit_key: key,
           value: value,
           message:
             "key `#{inspect(key)}` not present in #{type} at path `#{inspect(done_path)}`."
         )}
    end
  end

  defp perform_argument_subpath(
         value,
         step,
         argument,
         [key | remaining_path],
         done_path,
         intermediate_value
       )
       when is_list(intermediate_value) do
    if Keyword.keyword?(intermediate_value) do
      case Keyword.fetch(intermediate_value, key) do
        {:ok, intermediate_value} ->
          perform_argument_subpath(
            value,
            step,
            argument,
            remaining_path,
            [key | done_path],
            intermediate_value
          )

        :error ->
          {:error,
           ArgumentSubpathError.exception(
             step: step,
             argument: argument,
             culprit: intermediate_value,
             culprit_path: done_path,
             culprit_key: key,
             value: value,
             message:
               "key `#{inspect(key)}` not present in keyword list at path `#{inspect(done_path)}`."
           )}
      end
    else
      {:error,
       ArgumentSubpathError.exception(
         step: step,
         argument: argument,
         value: value,
         culprit: intermediate_value,
         culprit_key: List.first(done_path),
         culprit_path: done_path,
         message: "list at path `#{inspect(done_path)}` is not a keyword list."
       )}
    end
  end

  defp perform_argument_subpath(
         value,
         step,
         argument,
         _remaining_path,
         done_path,
         intermediate_value
       ) do
    {:error,
     ArgumentSubpathError.exception(
       step: step,
       argument: argument,
       value: value,
       culprit: intermediate_value,
       culprit_path: done_path,
       culprit_key: List.first(done_path),
       message: "value is neither a map or keyword list."
     )}
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
