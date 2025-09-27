# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule ReactorTest do
  @moduledoc false
  use ExUnit.Case
  alias Example.{HelloWorldReactor, Step.Greeter}
  alias Reactor.{Builder, Info, Planner}

  doctest Reactor

  describe "run/1..4" do
    defmodule BasicReactor do
      @moduledoc false
      use Reactor

      input :name

      step :split do
        argument :name, input(:name)
        run(fn %{name: name}, _ -> {:ok, String.split(name)} end)
      end

      step :reverse do
        argument :chunks, result(:split)
        run(fn %{chunks: chunks}, _ -> {:ok, Enum.reverse(chunks)} end)
      end

      step :join do
        argument :chunks, result(:reverse)
        run(fn %{chunks: chunks}, _ -> {:ok, Enum.join(chunks, " ")} end)
      end
    end

    test "it can run a module-based reactor directly" do
      assert {:ok, "McFly Marty"} = Reactor.run(BasicReactor, name: "Marty McFly")
    end

    test "it can run unplanned reactors" do
      {:ok, reactor} = Info.to_struct(BasicReactor)

      assert {:ok, "McFly Marty"} = Reactor.run(reactor, name: "Marty McFly")
    end

    test "it can run partially planned reactors" do
      {:ok, reactor} = Info.to_struct(BasicReactor)
      join_step = Enum.find(reactor.steps, &(&1.name == :join))
      {:ok, reactor} = Planner.plan(reactor)

      reactor = %{
        reactor
        | plan: Graph.delete_vertex(reactor.plan, join_step),
          steps: [join_step]
      }

      assert {:ok, "McFly Marty"} = Reactor.run(reactor, name: "Marty McFly")
    end

    test "it can return successful reactors" do
      assert {:ok, "Marty McFly", reactor} =
               Reactor.run(BasicReactor, %{name: "McFly Marty"}, %{}, fully_reversible?: true)

      assert reactor.state == :successful
    end
  end

  describe "undo/2" do
    defmodule UndoableReactor do
      use Reactor

      input :agent

      step :push_a do
        argument :agent, input(:agent)
        run &push(&1, :a)
        undo &undo/2
      end

      step :push_b do
        wait_for :push_a
        argument :agent, input(:agent)
        run &push(&1, :b)
        undo &undo/2
      end

      return :push_b

      def push(args, value) do
        Agent.update(args.agent, fn list -> [value | list] end)
        {:ok, value}
      end

      def undo(value, args) do
        Agent.update(args.agent, fn list -> List.delete(list, value) end)

        :ok
      end
    end

    test "previously successful reactors can be undone" do
      {:ok, pid} = Agent.start_link(fn -> [:z] end)

      assert {:ok, :b, reactor} =
               Reactor.run(UndoableReactor, %{agent: pid}, %{}, fully_reversible?: true)

      assert [:b, :a, :z] = Agent.get(pid, &Function.identity/1)

      assert :ok = Reactor.undo(reactor, %{})

      assert [:z] = Agent.get(pid, &Function.identity/1)
    end
  end
end
