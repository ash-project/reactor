# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.PlannerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Error.Internal.PlanError, Info, Planner}

  describe "plan/1" do
    test "when the argument is not a reactor, it returns an error" do
      {:error, %ArgumentError{} = error} = Planner.plan(:marty)
      assert Exception.message(error) =~ ~r/not a reactor/i
    end

    test "when the reactor has no existing plan, it creates one" do
      {:ok, reactor} = Info.to_struct(Example.BasicReactor)
      refute reactor.plan

      {:ok, reactor} = Planner.plan(reactor)
      assert reactor.plan
    end

    test "when the reactor already has a plan, it amends it" do
      reactor =
        Example.BasicReactor
        |> Info.to_struct!()
        |> Planner.plan!()
        |> Builder.add_step!(:second_step, Example.BasicReactor.DrinkingAgeVerifier)

      {:ok, reactor} = Planner.plan(reactor)
      assert [] = reactor.steps

      planned_step_names =
        reactor.plan
        |> Graph.vertices()
        |> MapSet.new(& &1.name)

      expected_step_names = MapSet.new([:verify, :second_step])

      assert MapSet.equal?(expected_step_names, planned_step_names)
    end

    test "it converts steps and arguments into a DAG" do
      {:ok, reactor} =
        Builder.new()
        |> Builder.add_step!(:a, Example.BasicReactor.DrinkingAgeVerifier)
        |> Builder.add_step!(:b, Example.BasicReactor.DrinkingAgeVerifier, a: {:result, :a})
        |> Planner.plan()

      assert [] = reactor.steps

      created_graph_vertices =
        reactor.plan
        |> Graph.vertices()
        |> MapSet.new(& &1.name)

      expected_graph_vertices = MapSet.new([:a, :b])
      assert MapSet.equal?(created_graph_vertices, expected_graph_vertices)

      created_graph_edges =
        reactor.plan
        |> Graph.edges()
        |> Enum.map(& &1.label)

      expected_graph_edges = [{:argument, :a, :for, :b}]

      assert created_graph_edges == expected_graph_edges
    end

    test "when the created graph would be cyclic, it returns an error" do
      assert {:error, %PlanError{} = error} =
               Builder.new()
               |> Builder.add_step!(:a, Example.BasicReactor.DrinkingAgeVerifier,
                 b: {:result, :b}
               )
               |> Builder.add_step!(:b, Example.BasicReactor.DrinkingAgeVerifier,
                 a: {:result, :a}
               )
               |> Planner.plan()

      assert Exception.message(error) =~ ~r/cyclic/i
    end

    test "when given an invalid step, it returns an error" do
      assert {:error, %PlanError{} = error} =
               Builder.new()
               |> Map.put(:steps, [%{name: :marty}])
               |> Planner.plan()

      assert Exception.message(error) =~ ~r/not a `Reactor.Step` struct/
    end

    test "when an argument depends on an unknown step, it returns an error" do
      assert {:error, %PlanError{} = error} =
               Builder.new()
               |> Builder.add_step!(:a, Example.BasicReactor.DrinkingAgeVerifier,
                 a: {:result, :b}
               )
               |> Planner.plan()

      assert Exception.message(error) =~ ~r/cannot be found/i
    end
  end
end
