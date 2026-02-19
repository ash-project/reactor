# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Executor.SyncTest do
  alias Reactor.Error.Invalid.RetriesExceededError, as: RetriesExceededError
  alias Reactor.Executor
  import Reactor.Executor.Sync
  use ExUnit.Case, async: true
  use Mimic

  defmodule TinyReactor do
    @moduledoc false
    use Reactor

    step :doable, Example.Step.Doable do
      max_retries 100
    end

    step :undoable, Example.Step.Undoable do
      argument :doable, result(:doable)
    end
  end

  setup do
    {:ok, reactor} = Reactor.Info.to_struct(TinyReactor)
    doable = Enum.find(reactor.steps, &(&1.name == :doable))
    undoable = Enum.find(reactor.steps, &(&1.name == :undoable))
    {:ok, reactor} = Reactor.Planner.plan(reactor)
    state = Executor.State.init()

    {:ok, reactor: reactor, state: state, doable: doable, undoable: undoable}
  end

  describe "run/3" do
    test "when there is no step to run, it tells the reactor to continue", %{
      reactor: reactor,
      state: state
    } do
      assert {:continue, ^reactor, ^state} = run(reactor, state, nil)
    end

    test "when the step asks to retry, it tells the reactor to recurse", %{
      reactor: reactor,
      state: state,
      doable: step
    } do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> :retry end)

      assert {:recurse, _, _} = run(reactor, state, step)
    end

    test "when the step asks to retry, it remains in the reactor plan", %{
      reactor: reactor,
      state: state,
      doable: step
    } do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> :retry end)

      assert {_, reactor, _} = run(reactor, state, step)
      assert Graph.has_vertex?(reactor.plan, step)
    end

    test "when the step asks to retry, it increments the retries in the reactor state", %{
      reactor: reactor,
      state: state,
      doable: step
    } do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> :retry end)

      state = %{state | retries: Map.put(state.retries, step.ref, 3)}
      assert {_, _, state} = run(reactor, state, step)
      assert Map.get(state.retries, step.ref) == 4
    end

    test "when the step asks to retry, and it has run out of retries, it tells the reactor to undo",
         %{reactor: reactor, state: state, doable: step} do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> :retry end)

      state = %{state | retries: Map.put(state.retries, step.ref, 100)}

      assert {:undo, _, %{errors: [%RetriesExceededError{}]}} =
               run(reactor, state, step)
    end

    test "when the step is successful it tells the reactor to recurse", %{
      reactor: reactor,
      state: state,
      doable: step
    } do
      assert {:recurse, _, _} = run(reactor, state, step)
    end

    test "when the step is successful and doable, the result is stored in the undo stack", %{
      reactor: reactor,
      state: state,
      undoable: step
    } do
      Example.Step.Undoable
      |> stub(:run, fn _, _, _ -> {:ok, :marty} end)

      reactor = inject_result(reactor, :doable, :doc)

      assert {_, reactor, _} = run(reactor, state, step)
      assert [{^step, :marty}] = reactor.undo
    end

    test "when the step is successful and is depended upon by other steps then it's result is stored in the reactor's intermediate results",
         %{reactor: reactor, state: state, doable: step} do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> {:ok, :marty} end)

      assert {_, reactor, _} = run(reactor, state, step)
      assert Map.get(reactor.intermediate_results, :doable) == :marty
    end

    test "when the step is successful it is removed from the reactor's plan", %{
      reactor: reactor,
      state: state,
      doable: step
    } do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> {:ok, :marty} end)

      assert {_, reactor, _} = run(reactor, state, step)
      refute Graph.has_vertex?(reactor.plan, step)
    end

    test "when the step is unsuccessful it tells the reactor to undo", %{
      reactor: reactor,
      state: state,
      doable: step
    } do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> {:error, "Only 1.20 giggawatts"} end)

      assert {:undo, _reactor, _state} = run(reactor, state, step)
    end

    test "when the step wants to halt, it tells the reactor to halt", %{
      reactor: reactor,
      state: state,
      doable: step
    } do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> {:halt, "Great Scott!"} end)

      assert {:halt, _reactor, _state} = run(reactor, state, step)
    end

    test "when the step wants to halt, it's result is stored in the reactor's intermediate results",
         %{reactor: reactor, state: state, doable: step} do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> {:halt, "Great Scott!"} end)

      assert {_, reactor, _state} = run(reactor, state, step)
      assert Map.get(reactor.intermediate_results, step.name) == "Great Scott!"
    end
  end

  defp inject_result(reactor, name, value),
    do: %{reactor | intermediate_results: Map.put(reactor.intermediate_results, name, value)}
end
