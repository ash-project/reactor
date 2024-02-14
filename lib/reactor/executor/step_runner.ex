defmodule Reactor.Executor.StepRunner do
  @moduledoc """
  Run an individual step, including compensation if possible.
  """
  alias Reactor.{Executor.ConcurrencyTracker, Executor.State, Step}
  import Reactor.Utils
  import Reactor.Argument, only: :macros
  require Logger

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
      result = do_run(step, arguments, context)
      Process.put(:__reactor__, metadata_stack)
      result
    end
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
      do_undo(value, step, arguments, context)
    end
  end

  defp do_undo(value, step, arguments, context, undo_count \\ 0)

  defp do_undo(_value, step, _arguments, _context, @max_undo_count),
    do: {:error, "`undo/4` retried #{@max_undo_count} times on step `#{inspect(step.name)}`."}

  defp do_undo(value, step, arguments, context, undo_count) do
    case Step.undo(step, value, arguments, context) do
      :ok -> :ok
      :retry -> do_undo(value, step, arguments, context, undo_count + 1)
    end
  end

  defp do_run(step, arguments, context) do
    case Step.run(step, arguments, context) do
      {:ok, value} -> {:ok, value, []}
      {:ok, value, steps} when is_list(steps) -> {:ok, value, steps}
      {:retry, reason} -> {:retry, reason}
      :retry -> :retry
      {:error, reason} -> maybe_compensate(step, reason, arguments, context)
      {:halt, value} -> {:halt, value}
    end
  rescue
    reason -> maybe_compensate(step, reason, arguments, context)
  end

  defp maybe_compensate(step, reason, arguments, context) do
    if Step.can?(step, :compensate) do
      compensate(step, reason, arguments, context)
    else
      {:error, reason}
    end
  end

  defp compensate(step, reason, arguments, context) do
    case Step.compensate(step, reason, arguments, context) do
      {:continue, value} -> {:ok, value}
      {:retry, reason} -> {:retry, reason}
      :retry -> {:retry, reason}
      {:error, reason} -> {:error, reason}
      :ok -> {:error, reason}
    end
  rescue
    error ->
      Logger.error(fn ->
        "Warning: step `#{inspect(step.name)}` `compensate/4` raised an error:\n" <>
          Exception.format(:error, error, __STACKTRACE__)
      end)

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
