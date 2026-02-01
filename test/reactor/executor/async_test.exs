# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Executor.AsyncTest do
  alias Reactor.Error.Invalid.RetriesExceededError, as: RetriesExceededError
  alias Reactor.Executor
  import Reactor.Executor.Async
  use ExUnit.Case, async: true

  defmodule TinyReactor do
    @moduledoc false
    use Reactor

    step :doable, Example.Step.Doable

    step :undoable, Example.Step.Undoable do
      argument :doable, result(:doable)
      max_retries 100
    end

    return :doable
  end

  setup do
    {:ok, pid} = Task.Supervisor.start_link([])
    {:ok, reactor} = Reactor.Info.to_struct(TinyReactor)
    doable = Enum.find(reactor.steps, &(&1.name == :doable))
    undoable = Enum.find(reactor.steps, &(&1.name == :undoable))
    {:ok, reactor} = Reactor.Planner.plan(reactor)
    state = Executor.State.init()
    {:ok, supervisor: pid, reactor: reactor, doable: doable, state: state, undoable: undoable}
  end

  describe "start_steps/3..4" do
    test "when there is no steps to run, it tells the reactor to continue",
         %{reactor: reactor, state: state} do
      assert {:continue, ^reactor, ^state} = start_steps(reactor, state, [])
    end

    test "when steps are started, it stores them in the state",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      assert {_, _reactor, state} = start_steps(reactor, state, [doable], supervisor)
      assert [{task, ^doable}] = Enum.to_list(state.current_tasks)
      assert is_struct(task, Task)
    end

    test "when steps are started, it tells the reactor to recurse",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      assert {:recurse, _reactor, _state} = start_steps(reactor, state, [doable], supervisor)
    end

    test "when steps are started, it adds an in edge to their reactor plan vertex",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      assert {_, reactor, _state} = start_steps(reactor, state, [doable], supervisor)
      assert Graph.in_degree(reactor.plan, doable) > 0
    end

    test "when steps are started, they are started in the expected supervisor",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      assert {_, _, _} = start_steps(reactor, state, [doable], supervisor)
      assert [pid] = Task.Supervisor.children(supervisor)
      assert is_pid(pid)
    end
  end

  describe "handle_completed_steps/2" do
    test "when there are no completed steps, it tells the reactor to continue",
         %{reactor: reactor, state: state} do
      assert {:continue, _reactor, _state} = handle_completed_steps(reactor, state)
    end

    test "when there are completed steps, it tells the reactor to recurse",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :marty, []} end)
      state = %{state | current_tasks: %{task => doable}}
      assert {:recurse, _reactor, _state} = handle_completed_steps(reactor, state)
    end

    test "when there are completed, but not undoable steps, it doesn't store them in the reactor's undo stacks",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :marty, []} end)
      state = %{state | current_tasks: %{task => doable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)

      assert Enum.empty?(reactor.undo)
    end

    test "when there are completed, undoable steps, it stores them in the reactor's undo stacks",
         %{reactor: reactor, state: state, undoable: undoable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :marty, []} end)
      state = %{state | current_tasks: %{task => undoable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)

      assert [{undoable, :marty}] == reactor.undo
    end

    test "when there are completed steps which are depended on by other steps, it stores the result in the reactor's intermediate results",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :marty, []} end)
      state = %{state | current_tasks: %{task => doable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)

      assert :marty = reactor.intermediate_results[doable.name]
    end

    test "when there are completed steps which are not depended on by other steps, it doesn't store the result in the reactor's intermediate results",
         %{reactor: reactor, state: state, undoable: undoable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :marty, []} end)
      state = %{state | current_tasks: %{task => undoable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)

      assert [] = Map.keys(reactor.intermediate_results)
    end

    test "when one of the steps asks to halt the reactor, it returns a halt tuple",
         %{reactor: reactor, state: state, supervisor: supervisor, doable: doable} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:halt, :marty} end)
      state = %{state | current_tasks: %{task => doable}}
      assert {:halt, _reactor, _state} = handle_completed_steps(reactor, state)
    end

    test "when one of the steps asks to halt the reactor, it stores any other undoable, completed steps in the reactor's undo stack",
         %{
           reactor: reactor,
           state: state,
           doable: doable,
           undoable: undoable,
           supervisor: supervisor
         } do
      task0 = Task.Supervisor.async_nolink(supervisor, fn -> {:halt, :marty} end)
      task1 = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :mcfly, []} end)

      state = %{state | current_tasks: %{task0 => doable, task1 => undoable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)
      assert [{^undoable, :mcfly}] = reactor.undo
    end

    test "when one of the steps asks to halt the reactor, it stores any other depended-upon results it stores the results in the reactor's intermediate results",
         %{
           reactor: reactor,
           state: state,
           doable: doable,
           undoable: undoable,
           supervisor: supervisor
         } do
      task0 = Task.Supervisor.async_nolink(supervisor, fn -> {:halt, :marty} end)
      task1 = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :mcfly, []} end)

      state = %{state | current_tasks: %{task1 => doable, task0 => undoable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)
      assert {doable.name, :mcfly} in Enum.to_list(reactor.intermediate_results)
    end

    test "when one of the steps asks to halt the reactor, it stores the steps' results in the reactor's intermediate results",
         %{reactor: reactor, state: state, doable: step, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:halt, :marty} end)

      state = %{state | current_tasks: %{task => step}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)
      assert [{step.name, :marty}] == Enum.to_list(reactor.intermediate_results)
    end

    test "when one of the steps returns an unrecoverable error, it returns an undo tuple",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> {:error, :marty} end)
      state = %{state | current_tasks: %{task => doable}}
      assert {:undo, _reactor, _state} = handle_completed_steps(reactor, state)
    end

    test "when one of the steps returns an unrecoverable error, it stores any other undoable, completed steps in the reactor's undo stack",
         %{
           reactor: reactor,
           state: state,
           doable: doable,
           undoable: undoable,
           supervisor: supervisor
         } do
      task0 = Task.Supervisor.async_nolink(supervisor, fn -> {:error, :marty} end)
      task1 = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :mcfly, []} end)

      state = %{state | current_tasks: %{task0 => doable, task1 => undoable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)
      assert [{^undoable, :mcfly}] = reactor.undo
    end

    test "when one of the steps returns an unrecoverable error, it stores any other depended-upon results it stores the results in the reactor's intermediate results",
         %{
           reactor: reactor,
           state: state,
           doable: doable,
           undoable: undoable,
           supervisor: supervisor
         } do
      task0 = Task.Supervisor.async_nolink(supervisor, fn -> {:error, :marty} end)
      task1 = Task.Supervisor.async_nolink(supervisor, fn -> {:ok, :mcfly, []} end)

      state = %{state | current_tasks: %{task1 => doable, task0 => undoable}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)
      assert [{doable.name, :mcfly}] == Enum.to_list(reactor.intermediate_results)
    end

    test "when one of the steps asks to retry, it puts the step back in the reactor plan",
         %{reactor: reactor, state: state, doable: step, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> :retry end)
      state = %{state | current_tasks: %{task => step}}
      assert {_, reactor, _state} = handle_completed_steps(reactor, state)
      assert Graph.has_vertex?(reactor.plan, step)
    end

    test "when one of the steps asks to retry, it sets the retry count for the step",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> :retry end)
      state = %{state | current_tasks: %{task => doable}}
      refute is_map_key(state.retries, doable.ref)

      assert {_, _reactor, state} = handle_completed_steps(reactor, state)
      assert state.retries[doable.ref] == 1
    end

    test "when one of the steps asks to retry (again), it increments the retry count for the step",
         %{reactor: reactor, state: state, doable: doable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> :retry end)
      state = %{state | current_tasks: %{task => doable}, retries: %{doable.ref => 1}}
      assert {_, _reactor, state} = handle_completed_steps(reactor, state)
      assert state.retries[doable.ref] == 2
    end

    test "when one of the steps asks to retry and has run out of retries, it triggers an undo",
         %{reactor: reactor, state: state, undoable: undoable, supervisor: supervisor} do
      task = Task.Supervisor.async_nolink(supervisor, fn -> :retry end)
      state = %{state | current_tasks: %{task => undoable}, retries: %{undoable.ref => 100}}

      assert {:undo, _reactor, %{errors: [%RetriesExceededError{}]}} =
               handle_completed_steps(reactor, state)
    end
  end
end
