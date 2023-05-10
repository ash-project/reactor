defmodule Reactor.Planner do
  @moduledoc """
  Build an execution plan for a Reactor.

  Converts any unplanned steps into vertices in a graph with directed edges
  between them representing their dependencies (arguments).
  """

  alias Reactor.Step
  import Reactor, only: :macros
  import Reactor.Argument, only: :macros

  @doc """
  Build an execution plan for a Reactor.

  Builds a graph of the step dependencies, resolves them and then builds an execution plan.
  """
  @spec plan(Reactor.t()) :: {:ok, Reactor.t()} | {:error, any}
  def plan(reactor) when not is_reactor(reactor),
    do: {:error, ArgumentError.exception("`reactor`: not a Reactor")}

  def plan(reactor) when is_nil(reactor.plan),
    do: plan(%{reactor | plan: empty_graph()})

  def plan(reactor) do
    with {:ok, graph} <- reduce_steps_into_graph(reactor.plan, reactor.steps),
         :ok <- assert_graph_not_cyclic(graph) do
      {:ok, %{reactor | steps: [], plan: graph}}
    end
  end

  defp empty_graph, do: Graph.new(type: :directed, vertex_identifier: & &1.ref)

  defp reduce_steps_into_graph(graph, steps) do
    steps_by_name =
      graph
      |> Graph.vertices()
      |> Enum.concat(steps)
      |> Map.new(&{&1.name, &1})

    Enum.reduce_while(steps, {:ok, graph}, fn
      step, {:ok, graph} when is_struct(step, Step) ->
        graph
        |> Graph.add_vertex(step, step.name)
        |> reduce_arguments_into_graph(step, steps_by_name)
        |> case do
          {:ok, graph} -> {:cont, {:ok, graph}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      not_step, _ ->
        {:halt, {:error, "Value `#{inspect(not_step)}` is not a `Reactor.Step` struct."}}
    end)
  end

  defp reduce_arguments_into_graph(graph, current_step, steps_by_name) do
    Enum.reduce_while(current_step.arguments, {:ok, graph}, fn
      argument, {:ok, graph} when is_argument(argument) ->
        dependency_name =
          case argument do
            argument when is_from_result(argument) -> argument.source.name
            argument when is_from_input(argument) -> {:input, argument.source.name}
          end

        case Map.fetch(steps_by_name, dependency_name) do
          {:ok, dependency} when dependency.name == current_step.name ->
            {:cont, {:ok, graph}}

          {:ok, dependency} ->
            {:cont,
             {:ok,
              Graph.add_edge(
                graph,
                dependency,
                current_step,
                label: {:argument, argument.name, :for, current_step.name}
              )}}

          :error ->
            {:halt,
             {:error,
              "Step `#{inspect(current_step.name)}` depends on the result of a step named `#{inspect(argument.source.name)}` which cannot be found"}}
        end

      _argument, _graph ->
        {:halt, {:error, ArgumentError.exception("`argument` is not an argument.")}}
    end)
  end

  defp assert_graph_not_cyclic(graph) do
    if Graph.is_acyclic?(graph) do
      :ok
    else
      {:error, "Reactor contains cyclic dependencies."}
    end
  end
end
