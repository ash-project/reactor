defmodule Reactor.Executor.StepRunnerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Reactor.{
    Argument,
    Builder,
    Error.Invalid.ArgumentSubpathError,
    Error.Invalid.MissingResultError,
    Error.Invalid.RunStepError,
    Error.Invalid.UndoRetriesExceededError,
    Executor.State,
    Template
  }

  import Reactor.Executor.StepRunner
  use Mimic

  setup do
    reactor = Builder.new()
    state = State.init()

    {:ok, reactor: reactor, state: state}
  end

  describe "run/1" do
    test "when the required argument cannot be fulfilled, it returns an error", %{
      reactor: reactor,
      state: state
    } do
      argument = Argument.from_result(:current_year, :time_circuits)
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable, [argument])
      step = reactor.steps |> hd()

      assert {:error, %MissingResultError{argument: %{source: %{name: :time_circuits}}}} =
               run(reactor, state, step, nil)
    end

    test "when the required argument cannot be subpathed, it returns an error", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :time_circuits, Example.Step.Undoable)

      argument = %Argument{
        name: :current_year,
        source: %Template.Result{name: :time_circuits, sub_path: [:year]}
      }

      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable, [argument])
      step = reactor.steps |> hd()
      reactor = %{reactor | intermediate_results: %{time_circuits: 1985}}

      assert {:error, %ArgumentSubpathError{argument: %{name: :current_year}}} =
               run(reactor, state, step, nil)
    end

    test "when the required argument can be subpathed, it calls the step with the correct arguments",
         %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :time_circuits, Example.Step.Undoable)

      argument = %Argument{
        name: :current_year,
        source: %Template.Result{name: :time_circuits, sub_path: [:year]}
      }

      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable, [argument])
      [marty, time_circuits] = reactor.steps
      reactor = %{reactor | intermediate_results: %{time_circuits.name => ~D[1985-10-26]}}

      Example.Step.Doable
      |> expect(:run, fn arguments, _, _ ->
        assert Map.keys(arguments) == [:current_year]
        assert arguments.current_year == 1985

        {:ok, :marty}
      end)

      assert {:ok, :marty, []} = run(reactor, state, marty, nil)
    end

    test "when the argument is named `:_` it is not passed to the step", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :time_circuits, Example.Step.Undoable)
      argument = Argument.from_result(:_, :time_circuits)
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable, [argument])
      [marty, time_circuits] = reactor.steps
      reactor = %{reactor | intermediate_results: %{time_circuits.name => 1985}}

      Example.Step.Doable
      |> expect(:run, fn arguments, _, _ ->
        assert Map.keys(arguments) == []

        {:ok, :marty}
      end)

      assert {:ok, :marty, []} = run(reactor, state, marty, nil)
    end

    test "it calls the step with the correct arguments", %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :time_circuits, Example.Step.Undoable)
      argument = Argument.from_result(:current_year, :time_circuits)
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable, [argument])
      [marty, time_circuits] = reactor.steps
      reactor = %{reactor | intermediate_results: %{time_circuits.name => 1985}}

      Example.Step.Doable
      |> expect(:run, fn arguments, _, _ ->
        assert Map.keys(arguments) == [:current_year]
        assert arguments.current_year == 1985

        {:ok, :marty}
      end)

      assert {:ok, :marty, []} = run(reactor, state, marty, nil)
    end

    test "when the step is successful, it returns an ok tuple", %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        {:ok, :marty, []}
      end)

      assert {:ok, :marty, []} = run(reactor, state, step, nil)
    end

    test "when the step asks to be retried, it returns a retry atom", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        :retry
      end)

      assert :retry = run(reactor, state, step, nil)
    end

    test "when the step asks to be retried with a backoff, it returns a backoff tuple", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        :retry
      end)
      |> stub(:backoff, fn _, _, _, _ ->
        100
      end)

      assert {:backoff, 100, :retry} = run(reactor, state, step, nil)
    end

    test "when a step returns an error and cannot be compensated, it returns an error tuple", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        {:error, :doc}
      end)

      assert {:error, %RunStepError{error: :doc}} = run(reactor, state, step, nil)
    end

    test "when a step raises an error it returns an error tuple", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        raise RuntimeError, "Not enough plutonium!"
      end)

      assert {:error, error} = run(reactor, state, step, nil)
      assert Exception.message(error) =~ "Not enough plutonium!"
    end

    test "when a step returns an error and can be compensated and the compensation says it can continue it returns an ok tuple",
         %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Compensable)
      step = reactor.steps |> hd()

      Example.Step.Compensable
      |> stub(:run, fn _, _, _ -> {:error, :doc} end)
      |> stub(:compensate, fn :doc, _, _, _ -> {:continue, :marty} end)

      assert {:ok, :marty, []} = run(reactor, state, step, nil)
    end

    test "when a step returns an error and can be compensated and the compensation succeed it returns an error tuple",
         %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Compensable)
      step = reactor.steps |> hd()

      Example.Step.Compensable
      |> stub(:run, fn _, _, _ -> {:error, :doc} end)
      |> stub(:compensate, fn :doc, _, _, _ -> :ok end)

      assert {:error, %RunStepError{error: :doc}} = run(reactor, state, step, nil)
    end

    test "when a step returns an error and can be compensated and the compensation asks for a retry it returns a retry tuple",
         %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Compensable)
      step = reactor.steps |> hd()

      Example.Step.Compensable
      |> stub(:run, fn _, _, _ -> {:error, :doc} end)
      |> stub(:compensate, fn :doc, _, _, _ -> :retry end)

      assert {:retry, %RunStepError{error: :doc}} = run(reactor, state, step, nil)
    end

    test "when a step returns an error and can be compensated and the compensation asks for a retry and a backoff it returns a backoff tuple",
         %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Compensable)
      step = reactor.steps |> hd()

      Example.Step.Compensable
      |> stub(:run, fn _, _, _ -> {:error, :doc} end)
      |> stub(:compensate, fn :doc, _, _, _ -> :retry end)
      |> stub(:backoff, fn _, _, _, _ -> 100 end)

      assert {:backoff, 100, {:retry, %RunStepError{error: :doc}}} =
               run(reactor, state, step, nil)
    end
  end

  describe "undo/3" do
    test "it calls undo on the step with the correct arguments", %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn value, arguments, _, _ ->
        assert value == :marty
        assert Enum.empty?(arguments)
        :ok
      end)

      undo(reactor, state, step, :marty, nil)
    end

    test "when the step can be undone it returns ok", %{reactor: reactor, state: state} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn _, _, _, _ -> :ok end)

      assert :ok = undo(reactor, state, step, :marty, nil)
    end

    test "when the step undo needs to be retried it eventually returns ok", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn _, _, _, _ -> :retry end)
      |> expect(:undo, fn _, _, _, _ -> :retry end)
      |> expect(:undo, fn _, _, _, _ -> :retry end)
      |> expect(:undo, fn _, _, _, _ -> :ok end)

      assert :ok = undo(reactor, state, step, :marty, nil)
    end

    test "when the step undo is stuck in a retry loop, it eventually returns an error", %{
      reactor: reactor,
      state: state
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn _, _, _, _ -> :retry end)

      assert {:error, %UndoRetriesExceededError{step: :marty}} =
               undo(reactor, state, step, :marty, nil)
    end
  end
end
