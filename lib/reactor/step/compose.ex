defmodule Reactor.Step.Compose do
  @moduledoc """
  A built-in step which can embed one reactor inside another.

  This is different to the `Builder.compose` and DSL `compose` methods.  Those
  methods build a new reactor by combining the steps of the two input reactors,
  whereas this step expands the provided reactor at runtime and dynamically
  inserts it's steps into the running reactor.

  If emitting the reactor's steps into the current reactor would be recursive,
  then the reactor is directly executed within the step using `Reactor.run/4`.
  """

  use Reactor.Step
  alias Reactor.{Argument, Builder, Error.ComposeError, Info, Step}
  import Reactor, only: :macros
  import Reactor.Argument, only: :macros
  import Reactor.Utils

  @doc false
  @impl true
  def run(arguments, context, options) do
    reactor = Keyword.fetch!(options, :reactor)
    reactor_id = get_reactor_id(reactor)

    context
    |> get_composed_reactors()
    |> MapSet.member?(reactor_id)
    |> if do
      handle_recursive_reactor(reactor, arguments, context)
    else
      handle_non_recursive_reactor(reactor, arguments, context)
    end
  end

  defp handle_recursive_reactor(reactor, arguments, context),
    do: Reactor.run(reactor, arguments, context, [])

  defp handle_non_recursive_reactor(reactor, arguments, context) when is_atom(reactor) do
    with {:ok, reactor} <- Info.to_struct(reactor) do
      handle_non_recursive_reactor(reactor, arguments, context)
    end
  end

  defp handle_non_recursive_reactor(reactor, arguments, context) do
    current_step = Map.fetch!(context, :current_step)

    with :ok <- validate_arguments_match_inputs(arguments, reactor),
         :ok <- validate_reactor_has_return(reactor),
         {:ok, inner_steps} <- rewrite_steps(reactor, current_step.name, arguments),
         {:ok, recursion_step} <- create_recursion_step(reactor, current_step.name) do
      steps =
        inner_steps
        |> Enum.concat([recursion_step])

      {:ok, nil, steps}
    end
  end

  defp get_reactor_id(reactor) when is_atom(reactor), do: reactor
  defp get_reactor_id(reactor) when is_reactor(reactor), do: reactor.id

  defp get_composed_reactors(context) when not is_nil(context.private.composed_reactors),
    do: context.private.composed_reactors

  defp get_composed_reactors(_context), do: MapSet.new()

  defp validate_reactor_has_return(reactor) when is_nil(reactor.return),
    do:
      {:error,
       ComposeError.exception(
         inner_reactor: reactor,
         message: "The inner Reactor must have an explicit return value."
       )}

  defp validate_reactor_has_return(reactor) do
    if Enum.any?(reactor.steps, &(&1.name == reactor.return)) do
      :ok
    else
      {:error,
       ComposeError.exception(
         inner_reactor: reactor,
         message:
           "The inner Reactor return value does not correspond with an existing Reactor step."
       )}
    end
  end

  defp create_recursion_step(reactor, name) do
    Builder.new_step(
      name,
      {Step.AnonFn, fun: fn args, _, _ -> {:ok, args.value} end},
      [value: {:result, {__MODULE__, name, reactor.return}}],
      max_retries: 0
    )
  end

  defp validate_arguments_match_inputs(arguments, reactor) do
    argument_names = arguments |> Map.keys() |> MapSet.new()
    input_names = MapSet.new(reactor.inputs)

    input_names
    |> MapSet.difference(argument_names)
    |> Enum.to_list()
    |> case do
      [] ->
        :ok

      [input] ->
        {:error,
         ComposeError.exception(
           inner_reactor: reactor,
           arguments: arguments,
           message: "Missing argument for input `#{input}`"
         )}

      inputs ->
        inputs = sentence(inputs, &"`#{&1}`", ", ", " and ")

        {:error,
         ComposeError.exception(
           inner_reactor: reactor,
           arguments: arguments,
           message: "Missing arguments for inputs #{inputs}"
         )}
    end
  end

  defp rewrite_steps(reactor, name, inputs) when not is_nil(reactor.plan) do
    steps =
      reactor.plan
      |> Graph.vertices()
      |> Enum.concat(reactor.steps)

    rewrite_steps(%{reactor | steps: steps, plan: nil}, name, inputs)
  end

  defp rewrite_steps(reactor, name, inputs) do
    reactor.steps
    |> map_while_ok(&rewrite_step(&1, name, inputs))
  end

  defp rewrite_step(step, name, inputs) do
    with {:ok, arguments} <- map_while_ok(step.arguments, &rewrite_argument(&1, name, inputs)) do
      {:ok,
       %{
         step
         | arguments: arguments,
           name: {__MODULE__, name, step.name},
           impl: {Step.ComposeWrapper, original: step.impl, prefix: [__MODULE__, name]}
       }}
    end
  end

  defp rewrite_argument(argument, _name, inputs) when is_from_input(argument) do
    value = Map.fetch!(inputs, argument.source.name)
    {:ok, Argument.from_value(argument.name, value)}
  end

  defp rewrite_argument(argument, name, _inputs) when is_from_result(argument),
    do: {:ok, Argument.from_result(argument.name, {__MODULE__, name, argument.source.name})}

  defp rewrite_argument(argument, _name, _inputs) when is_from_value(argument),
    do: {:ok, argument}
end
