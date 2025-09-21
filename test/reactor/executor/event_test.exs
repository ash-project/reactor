# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Executor.EventTest do
  use ExUnit.Case, async: true

  alias Reactor.Error.Invalid.CompensateStepError
  alias Reactor.Error.Invalid.RunStepError
  alias Reactor.Error.Invalid.UndoRetriesExceededError
  alias Reactor.Error.Invalid.UndoStepError

  defmodule EventMiddleware do
    use Reactor.Middleware

    @moduledoc false
    def event(event, _step, context) do
      Agent.update(context.event_agent, fn events -> [event | events] end)

      :ok
    end
  end

  def run(reactor, args, opts \\ []) do
    {:ok, pid} = Agent.start_link(fn -> [] end)

    reactor.reactor()
    |> Reactor.Builder.ensure_middleware!(EventMiddleware)
    |> Reactor.run(args, %{event_agent: pid}, opts)

    Agent.get(pid, fn events -> Enum.reverse(events) end)
  end

  describe "step run events" do
    defmodule StepReactor do
      @moduledoc false
      use Reactor

      input :step_result

      step :echo do
        argument :step_result, input(:step_result)
        max_retries 0

        run fn arguments, _ ->
          arguments.step_result
        end
      end
    end

    test "successful step" do
      assert [
               {:run_start, _},
               {:run_complete, :marty}
             ] =
               run(StepReactor, %{step_result: {:ok, :marty}}, async?: false)
    end

    test "retry step" do
      assert [
               {:run_start, _},
               :run_retry
             ] =
               run(StepReactor, %{step_result: :retry}, async?: false)
    end

    test "fail step" do
      assert [
               {:run_start, _},
               {:run_error, %RunStepError{error: :marty}}
             ] =
               run(StepReactor, %{step_result: {:error, :marty}}, async?: false)
    end

    test "halt step" do
      assert [
               {:run_start, _},
               {:run_halt, :marty}
             ] =
               run(StepReactor, %{step_result: {:halt, :marty}}, async?: false)
    end
  end

  describe "compensation events" do
    defmodule CompensateReactor do
      @moduledoc false
      use Reactor

      input :compensation_result

      step :fail do
        argument :compensation_result, input(:compensation_result)
        max_retries 1

        run fn _, _ ->
          {:error, :fail}
        end

        compensate fn _, arguments, _ ->
          arguments.compensation_result
        end
      end
    end

    test "successful compensation events" do
      assert [
               {:run_start, _},
               {:run_error, %RunStepError{error: :fail}},
               {:compensate_start, %RunStepError{error: :fail}},
               :compensate_complete
             ] =
               run(CompensateReactor, %{compensation_result: :ok}, async?: false)
    end

    test "compensation retries" do
      assert [
               {:run_start, _},
               {:run_error, %RunStepError{error: :fail}},
               {:compensate_start, %RunStepError{error: :fail}},
               :compensate_retry,
               {:run_start, _},
               {:run_error, %RunStepError{error: :fail}},
               {:compensate_start, %RunStepError{error: :fail}},
               :compensate_retry
             ] = run(CompensateReactor, %{compensation_result: :retry}, async?: false)
    end

    test "compensation failure" do
      assert [
               {:run_start, _},
               {:run_error, %RunStepError{error: :fail}},
               {:compensate_start, %RunStepError{error: :fail}},
               {:compensate_error, %CompensateStepError{error: :cant_compensate}}
             ] =
               run(CompensateReactor, %{compensation_result: {:error, :cant_compensate}},
                 async?: false
               )
    end

    test "compensation complete" do
      assert [
               {:run_start, _},
               {:run_error, %RunStepError{error: :fail}},
               {:compensate_start, %RunStepError{error: :fail}},
               :compensate_complete
             ] =
               run(CompensateReactor, %{compensation_result: :ok}, async?: false)
    end

    test "compensation continue" do
      assert [
               {:run_start, _},
               {:run_error, %RunStepError{error: :fail}},
               {:compensate_start, %RunStepError{error: :fail}},
               {:compensate_continue, :all_is_well}
             ] =
               run(CompensateReactor, %{compensation_result: {:continue, :all_is_well}},
                 async?: false
               )
    end
  end

  describe "undo events" do
    defmodule UndoReactor do
      @moduledoc false
      use Reactor

      input :undo_result

      step :undo_step do
        argument :undo_result, input(:undo_result)

        run fn _, _ ->
          {:ok, :marty}
        end

        undo fn _, arguments, _ ->
          arguments.undo_result
        end
      end

      step :fail do
        wait_for :undo_step
        run fn _, _ -> {:error, :doc_brown} end
      end
    end

    test "successful undo" do
      assert [
               {:run_start, _},
               {:run_complete, :marty},
               {:run_start, _},
               {:run_error, %RunStepError{error: :doc_brown}},
               :undo_start,
               :undo_complete
             ] =
               run(UndoReactor, %{undo_result: :ok}, async?: false)
    end

    test "undo retry" do
      assert [
               {:run_start, _},
               {:run_complete, :marty},
               {:run_start, _},
               {:run_error, %RunStepError{error: :doc_brown}},
               :undo_start,
               :undo_retry,
               :undo_retry,
               :undo_retry,
               :undo_retry,
               :undo_retry,
               {:undo_error, %UndoRetriesExceededError{}}
             ] =
               run(UndoReactor, %{undo_result: :retry}, async?: false)
    end

    test "undo retry with reason" do
      assert [
               {:run_start, %{undo_result: {:retry, :einstein}}},
               {:run_complete, :marty},
               {:run_start, %{}},
               {:run_error, %RunStepError{error: :doc_brown}},
               :undo_start,
               {:undo_retry, :einstein},
               {:undo_retry, :einstein},
               {:undo_retry, :einstein},
               {:undo_retry, :einstein},
               {:undo_retry, :einstein},
               {:undo_error, %UndoRetriesExceededError{}}
             ] =
               run(UndoReactor, %{undo_result: {:retry, :einstein}}, async?: false)
    end

    test "undo error" do
      assert [
               {:run_start, _},
               {:run_complete, :marty},
               {:run_start, _},
               {:run_error, %RunStepError{error: :doc_brown}},
               :undo_start,
               {:undo_error, %UndoStepError{error: :einstein}}
             ] = run(UndoReactor, %{undo_result: {:error, :einstein}}, async?: false)
    end
  end

  describe "process events" do
    defmodule ProcessReactor do
      @moduledoc false
      use Reactor

      step :process do
        run fn _, _ -> {:ok, self()} end
      end
    end

    test "process events" do
      assert [
               {:process_start, pid},
               {:run_start, %{}},
               {:run_complete, pid},
               {:process_terminate, pid}
             ] = run(ProcessReactor, %{})
    end
  end
end
