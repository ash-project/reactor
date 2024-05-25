defmodule Reactor.Builder.Compose do
  @moduledoc """
  Handle composition of Reactors for the builder.

  The composition logic was getting complicated enough that it seemed sensible
  to extract it from the builder - if only to aid readability.

  You should not use this module directly, but instead use
  `Reactor.Builder.compose/4`.
  """
  import Reactor, only: :macros
  import Reactor.Argument, only: :macros
  import Reactor.Utils
  alias Reactor.{Argument, Builder, Error.Internal.ComposeError, Step}

  @doc """
  Compose another Reactor inside this one.
  """
  @spec compose(Reactor.t(), atom, Reactor.t() | module, [Builder.step_argument()]) ::
          {:ok, Reactor.t()} | {:error, any}
  def compose(reactor, name, inner_reactor, arguments) when is_atom(inner_reactor) do
    if compose_would_be_recursive?(reactor, inner_reactor) do
      do_runtime_compose(reactor, name, inner_reactor, arguments)
    else
      case Reactor.Info.to_struct(inner_reactor) do
        {:ok, inner_reactor} -> compose(reactor, name, inner_reactor, arguments)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def compose(reactor, name, inner_reactor, arguments) when not is_nil(inner_reactor.plan) do
    steps =
      inner_reactor.plan
      |> Graph.vertices()
      |> Enum.concat(inner_reactor.steps)

    compose(
      reactor,
      name,
      %{inner_reactor | steps: steps, plan: nil},
      arguments
    )
  end

  def compose(reactor, name, inner_reactor, arguments)
      when is_reactor(reactor) and is_atom(name) and is_reactor(inner_reactor) and
             is_list(arguments) do
    if compose_would_be_recursive?(reactor, inner_reactor.id) do
      do_runtime_compose(reactor, name, inner_reactor, arguments)
    else
      do_static_compose(reactor, name, inner_reactor, arguments)
    end
  end

  defp do_runtime_compose(reactor, name, inner_reactor, arguments) do
    Builder.add_step(reactor, name, {Step.Compose, reactor: inner_reactor}, arguments,
      max_retries: 0
    )
  end

  def do_static_compose(reactor, name, inner_reactor, arguments) do
    with {:ok, arguments} <- assert_all_are_arguments(arguments),
         :ok <- assert_arguments_match_inner_reactor_inputs(arguments, inner_reactor),
         {:ok, steps} <- rewrite_steps(inner_reactor, name, arguments),
         {:ok, return} <- build_return_step(reactor, inner_reactor, name) do
      steps =
        steps
        |> Enum.concat(reactor.steps)
        |> Enum.concat([return])

      reactor =
        reactor
        |> Map.put(:steps, steps)
        |> add_composed_reactor(inner_reactor)

      {:ok, reactor}
    end
  end

  defp get_composed_reactors(reactor) do
    reactor
    |> Map.get(:context, %{})
    |> Map.get(:private, %{})
    |> Map.get(:composed_reactors, MapSet.new())
  end

  defp add_composed_reactor(reactor, inner_reactor) do
    composed_reactors =
      reactor
      |> get_composed_reactors()
      |> MapSet.put(inner_reactor.id)

    %{
      reactor
      | context: deep_merge(reactor.context, %{private: %{composed_reactors: composed_reactors}})
    }
  end

  defp compose_would_be_recursive?(reactor, id) when reactor.id == id, do: true

  defp compose_would_be_recursive?(reactor, id) do
    reactor
    |> get_composed_reactors()
    |> MapSet.member?(id)
  end

  defp build_return_step(reactor, inner_reactor, _name) when is_nil(inner_reactor.return),
    do:
      {:error,
       ComposeError.exception(
         outer_reactor: reactor,
         inner_reactor: inner_reactor,
         message: "The inner Reactor must have an explicit return value."
       )}

  defp build_return_step(_reactor, inner_reactor, name) do
    {:ok,
     %Step{
       arguments: [
         Argument.from_result(:value, {:__reactor__, :compose, name, inner_reactor.return})
       ],
       name: name,
       async?: true,
       impl: {Step.ReturnArgument, argument: :value},
       max_retries: 0,
       ref: name
     }}
  end

  defp assert_all_are_arguments(arguments) do
    arguments
    |> map_while_ok(&Argument.Build.build/1)
    |> and_then(&{:ok, List.flatten(&1)})
  end

  defp assert_arguments_match_inner_reactor_inputs(arguments, inner_reactor) do
    required_arguments = MapSet.new(inner_reactor.inputs)
    provided_arguments = MapSet.new(arguments, & &1.name)

    required_arguments
    |> MapSet.difference(provided_arguments)
    |> Enum.to_list()
    |> case do
      [] ->
        :ok

      [missing] ->
        {:error,
         ComposeError.exception(
           inner_reactor: inner_reactor,
           arguments: arguments,
           message: "Missing argument for `#{missing}` input."
         )}

      missing ->
        missing = sentence(missing, &"`#{&1}`", ", ", " and ")

        {:error,
         ComposeError.exception(
           inner_reactor: inner_reactor,
           arguments: arguments,
           message: "Missing arguments for the following Reactor inputs; #{missing}"
         )}
    end
  end

  defp rewrite_steps(reactor, name, input_arguments) do
    input_arguments = Map.new(input_arguments, &{&1.name, &1})

    reactor
    |> extract_steps()
    |> map_while_ok(&rewrite_step(&1, name, input_arguments))
  end

  defp rewrite_step(step, name, input_arguments) do
    with {:ok, arguments} <- rewrite_arguments(step.arguments, name, input_arguments) do
      step = %{
        step
        | arguments: arguments,
          name: {:__reactor__, :compose, name, step.name},
          impl: {Step.ComposeWrapper, original: step.impl, prefix: [:__reactor__, :compose, name]}
      }

      {:ok, step}
    end
  end

  defp extract_steps(reactor) when is_nil(reactor.plan), do: reactor.steps

  defp extract_steps(reactor) do
    reactor.plan
    |> Graph.vertices()
    |> Enum.concat(reactor.steps)
  end

  defp rewrite_arguments(arguments, name, input_arguments),
    do: map_while_ok(arguments, &rewrite_argument(&1, name, input_arguments))

  defp rewrite_argument(argument, _name, input_arguments) when is_from_input(argument) do
    input_argument = Map.fetch!(input_arguments, argument.source.name)

    {:ok, %{argument | source: input_argument.source}}
  end

  defp rewrite_argument(argument, name, _input_arguments) when is_from_result(argument) do
    source = %{argument.source | name: {:__reactor__, :compose, name, argument.source.name}}

    {:ok, %{argument | source: source}}
  end

  defp rewrite_argument(argument, _name, _input_arguments) when is_from_value(argument),
    do: {:ok, argument}
end
