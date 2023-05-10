defmodule Reactor.Executor.StepRunner do
  @moduledoc """
  Run an individual step, including compensation if possible.
  """
  alias Reactor.{Step, Template}
  require Logger

  @max_undo_count 5

  @doc """
  Collect the arguments and and run a step, with compensation if required.
  """
  @spec run(Reactor.t(), Step.t()) :: {:ok, any, [Step.t()]} | :retry | {:error | :halt, any}
  def run(reactor, step) do
    with {:ok, arguments} <- get_step_arguments(reactor, step),
         {module, options} <- module_and_opts(step) do
      do_run(module, options, arguments, reactor.context)
    end
  end

  @doc """
  Undo a step if possible.
  """
  @spec undo(Reactor.t(), Step.t(), any) :: :ok | {:error, any}
  def undo(reactor, step, value) do
    with {:ok, arguments} <- get_step_arguments(reactor, step),
         {module, options} <- module_and_opts(step) do
      do_undo(value, module, options, arguments, reactor.context)
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
    if module.can?(:compensate) do
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
    Enum.reduce_while(step.arguments, {:ok, %{}}, fn argument, {:ok, arguments} ->
      with %Template.Result{name: dependency_name} <- argument.source,
           {:ok, value} <- Map.fetch(reactor.intermediate_results, dependency_name) do
        {:cont, {:ok, Map.put(arguments, argument.name, value)}}
      else
        %Template.Input{} ->
          {:halt,
           {:error,
            "Step `#{inspect(step.name)}` argument `#{inspect(argument.name)}` is invalid"}}

        :error ->
          {:halt,
           {:error,
            "Step `#{inspect(step.name)}` argument `#{inspect(argument.name)}` is missing"}}
      end
    end)
  end
end
