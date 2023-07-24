defmodule Reactor.Executor.StepRunner do
  @moduledoc """
  Run an individual step, including compensation if possible.
  """
  alias Reactor.{Executor.ConcurrencyTracker, Step}
  import Reactor.Utils
  import Reactor.Argument, only: :macros
  require Logger

  @max_undo_count 5

  @doc """
  Collect the arguments and and run a step, with compensation if required.
  """
  @spec run(Reactor.t(), Step.t(), ConcurrencyTracker.pool_key()) ::
          {:ok, any, [Step.t()]} | :retry | {:error | :halt, any}
  def run(reactor, step, concurrency_key) do
    with {:ok, arguments} <- get_step_arguments(reactor, step),
         {module, options} <- module_and_opts(step),
         {:ok, context} <- build_context(reactor, step, concurrency_key),
         {:ok, arguments} <- maybe_replace_arguments(arguments, context) do
      do_run(module, options, arguments, context)
    end
  end

  @doc """
  Undo a step if possible.
  """
  @spec undo(Reactor.t(), Step.t(), any, ConcurrencyTracker.pool_key()) :: :ok | {:error, any}
  def undo(reactor, step, value, concurrency_key) do
    with {:ok, arguments} <- get_step_arguments(reactor, step),
         {module, options} <- module_and_opts(step),
         {:ok, context} <- build_context(reactor, step, concurrency_key),
         {:ok, arguments} <- maybe_replace_arguments(arguments, context) do
      do_undo(value, module, options, arguments, context)
    end
  end

  defp module_and_opts(%{impl: {module, options}}) when is_atom(module) and is_list(options),
    do: {module, options}

  defp module_and_opts(%{impl: module}) when is_atom(module), do: {module, []}

  defp do_undo(value, module, options, arguments, context, undo_count \\ 0)

  defp do_undo(_value, module, _options, _arguments, _context, @max_undo_count),
    do: {:error, "`#{inspect(module)}.undo/4` retried #{@max_undo_count} times."}

  defp do_undo(value, module, options, arguments, context, undo_count) do
    case module.undo(value, arguments, context, options) do
      :ok -> :ok
      :retry -> do_undo(value, module, options, arguments, context, undo_count + 1)
    end
  end

  defp do_run(module, options, arguments, context) do
    case module.run(arguments, context, options) do
      {:ok, value} -> {:ok, value, []}
      {:ok, value, steps} when is_list(steps) -> {:ok, value, steps}
      :retry -> :retry
      {:error, reason} -> maybe_compensate(module, reason, arguments, context, options)
      {:halt, value} -> {:halt, value}
    end
  rescue
    reason -> maybe_compensate(module, reason, arguments, context, options)
  end

  defp maybe_compensate(module, reason, arguments, context, options) do
    if Step.can?(module, :compensate) do
      compensate(module, reason, arguments, context, options)
    else
      {:error, reason}
    end
  end

  defp compensate(module, reason, arguments, context, options) do
    case module.compensate(reason, arguments, context, options) do
      {:continue, value} -> {:ok, value}
      :retry -> :retry
      :ok -> {:error, reason}
    end
  rescue
    error ->
      Logger.error(fn ->
        "Warning: `#{inspect(module)}.compensate/4` raised an error:\n" <>
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

  defp build_context(reactor, step, concurrency_key) do
    context =
      step.context
      |> deep_merge(reactor.context)
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
