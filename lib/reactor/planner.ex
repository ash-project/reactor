defmodule Reactor.Planner do
  @moduledoc """
  Build an execution plan for a Reactor.

  Converts any unplanned steps into vertices in a graph with directed edges
  between them representing their dependencies (arguments).
  """

  alias Reactor.{Error.PlanError, Step}
  import Reactor, only: :macros
  import Reactor.Argument, only: :macros
  import Reactor.Utils

  @doc """
  Build an execution plan for a Reactor.

  Builds a graph of the step dependencies, resolves them and then builds an execution plan.
  """
  @spec plan(Reactor.t()) :: {:ok, Reactor.t()} | {:error, any}
  def plan(reactor) when not is_reactor(reactor),
    do: {:error, argument_error(:reactor, "not a Reactor", reactor)}

  def plan(reactor) when is_nil(reactor.plan),
    do: plan(%{reactor | plan: empty_graph()})

  def plan(reactor) do
    with {:ok, graph} <- reduce_steps_into_graph(reactor.plan, reactor.steps),
         :ok <- assert_graph_not_cyclic(reactor, graph) do
      {:ok, %{reactor | steps: [], plan: graph}}
    end
  end

  @doc """
  Raising version of `plan/1`.
  """
  @spec plan!(Reactor.t()) :: Reactor.t() | no_return
  def plan!(reactor) do
    case plan(reactor) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc false
  def get_ref(%{ref: ref}), do: ref

  defp empty_graph, do: Graph.new(type: :directed, vertex_identifier: &__MODULE__.get_ref/1)

  defp reduce_steps_into_graph(graph, steps) do
    steps_by_name =
      graph
      |> Graph.vertices()
      |> Enum.concat(steps)
      |> Map.new(&{&1.name, &1})

    steps
    |> reduce_while_ok(graph, fn
      step, graph when is_struct(step, Step) ->
        graph
        |> Graph.add_vertex(step, step.name)
        |> reduce_arguments_into_graph(step, steps_by_name)

      not_step, _ ->
        {:error,
         PlanError.exception(
           graph: graph,
           step: not_step,
           message: "Value is not a `Reactor.Step` struct."
         )}
    end)
  end

  defp reduce_arguments_into_graph(graph, current_step, steps_by_name) do
    reduce_while_ok(current_step.arguments, graph, fn
      argument, graph when is_argument(argument) and is_from_result(argument) ->
        dependency_name = argument.source.name

        case Map.fetch(steps_by_name, dependency_name) do
          {:ok, dependency} when dependency.name == current_step.name ->
            {:ok, graph}

          {:ok, dependency} ->
            {:ok,
             Graph.add_edge(graph, dependency, current_step,
               label: {:argument, argument.name, :for, current_step.name}
             )}

          :error ->
            {:error,
             PlanError.exception(
               graph: graph,
               step: current_step,
               message:
                 "Step `#{inspect(current_step.name)}` depends on the result of a step named `#{inspect(argument.source.name)}` which cannot be found"
             )}
        end

      argument, graph
      when is_argument(argument) and (is_from_input(argument) or is_from_value(argument)) ->
        {:ok, graph}
    end)
  end

  defp assert_graph_not_cyclic(reactor, graph) do
    if Graph.is_acyclic?(graph) do
      :ok
    else
      {:error,
       PlanError.exception(
         reactor: reactor,
         graph: graph,
         message: "Reactor contains cyclic dependencies."
       )}
    end
  end
end
