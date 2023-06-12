defmodule Reactor.Step.ComposeWrapper do
  @moduledoc """
  When doing run-time composition of Reactors we need to dynamically rewrite any
  dynamically emitted steps to have the correct namespace.

  Yes, this gets hairy, fast.

  This is dynamically injected into steps by `Reactor.Step.Compose` - you
  probably don't want to use this unless you're sure what you're doing.

  ## Options

    * `original` - the original value of the Step's `impl` key.
    * `prefix` - a list of values to be placed in the `name` before the original value.
  """

  use Reactor.Step
  alias Reactor.Argument
  import Reactor.Argument, only: :macros
  import Reactor.Utils

  @doc false
  @impl true
  def run(arguments, context, options) do
    with {:ok, impl} <- validate_original_option(options, context.current_step),
         {:ok, prefix} <- validate_prefix_option(options, context.current_step) do
      case do_run(impl, arguments, context) do
        {:ok, value} -> {:ok, value}
        {:ok, value, steps} -> {:ok, value, rewrite_steps(steps, prefix)}
        {stop, reason} when stop in ~w[halt error]a -> {stop, reason}
      end
    end
  end

  @doc false
  @impl true
  def compensate(reason, arguments, context, options) do
    case get_original_option(options, context.current_step) do
      {:ok, {impl, opts}} -> impl.compensate(reason, arguments, context, opts)
      {:ok, impl} -> impl.compensate(reason, arguments, context, [])
      {:error, _} -> :ok
    end
  rescue
    UndefinedFunctionError -> :ok
  end

  @doc false
  @impl true
  def undo(value, arguments, context, options) do
    case get_original_option(options, context.current_step) do
      {:ok, {impl, opts}} -> impl.undo(value, arguments, context, opts)
      {:ok, impl} -> impl.undo(value, arguments, context, [])
      {:error, reason} -> {:error, reason}
    end
  rescue
    UndefinedFunctionError -> :ok
  end

  defp validate_original_option(options, current_step) do
    with {:ok, original} <- get_original_option(options, current_step),
         {module, opts} <- get_module_and_options(original) do
      if Spark.implements_behaviour?(module, Reactor.Step) do
        {:ok, {module, opts}}
      else
        {:error,
         argument_error(
           :options,
           "Step `#{current_step.name}` module `#{inspect(module)}` does not implement the `Reactor.Step` behaviour.",
           opts
         )}
      end
    end
  end

  defp get_original_option(options, current_step) do
    with :error <- Keyword.fetch(options, :original) do
      {:error,
       argument_error(
         :options,
         "Step `#{current_step.name}` is missing the `original` option.",
         options
       )}
    end
  end

  defp validate_prefix_option(options, current_step) do
    case Keyword.fetch(options, :prefix) do
      {:ok, [_ | _] = prefix} ->
        {:ok, prefix}

      :error ->
        {:error,
         argument_error(
           :options,
           "Step `#{current_step.name}` has missing `prefix` option.",
           options
         )}

      _ ->
        {:error,
         argument_error(
           :options,
           "Step `#{current_step.name}` has invalid `prefix` option.",
           options
         )}
    end
  end

  defp get_module_and_options(impl) when is_atom(impl), do: {impl, []}

  defp get_module_and_options({impl, options}) when is_atom(impl) and is_list(options),
    do: {impl, options}

  defp do_run({module, options}, arguments, context) when is_atom(module) and is_list(options),
    do: module.run(arguments, context, options)

  defp rewrite_steps(steps, prefix) do
    steps
    |> Enum.map(fn step ->
      name =
        prefix
        |> Enum.concat([step.name])
        |> List.to_tuple()

      arguments = Enum.map(step.arguments, &rewrite_argument(&1, prefix))

      %{step | name: name, arguments: arguments}
    end)
  end

  defp rewrite_argument(argument, prefix) when is_from_result(argument) do
    source =
      prefix
      |> Enum.concat([argument.source.name])
      |> List.to_tuple()

    Argument.from_result(argument.name, source)
  end

  defp rewrite_argument(argument, _prefix)
       when is_from_input(argument) or is_from_value(argument),
       do: argument
end
