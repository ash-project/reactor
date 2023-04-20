defmodule Reactor.Executor.StepRunnerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Argument, Builder}
  import Reactor.Executor.StepRunner
  use Mimic

  setup do
    reactor = Builder.new()
    {:ok, reactor: reactor}
  end

  describe "run/1" do
    test "when the required argument cannot be fulfilled, it returns an error", %{
      reactor: reactor
    } do
      argument = Argument.from_result(:current_year, :time_circuits)
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable, [argument])
      step = reactor.steps |> hd()

      assert {:error, reason} = run(reactor, step)
      assert reason =~ "argument `:current_year` is missing"
    end

    test "it calls the step with the correct arguments", %{reactor: reactor} do
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

      assert {:ok, :marty, []} = run(reactor, marty)
    end

    test "when the step is successful, it returns an ok tuple", %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        {:ok, :marty, []}
      end)

      assert {:ok, :marty, []} = run(reactor, step)
    end

    test "when the step asks to be retried, it returns a retry atom", %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        :retry
      end)

      assert :retry = run(reactor, step)
    end

    test "when a step returns an error and cannot be compensated, it returns an error tuple", %{
      reactor: reactor
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        {:error, :doc}
      end)

      assert {:error, :doc} = run(reactor, step)
    end

    test "when a step raises an error it returns an error tuple", %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Doable)
      step = reactor.steps |> hd()

      Example.Step.Doable
      |> stub(:run, fn _, _, _ ->
        raise RuntimeError, "Not enough plutonium!"
      end)

      assert {:error, error} = run(reactor, step)
      assert is_struct(error, RuntimeError)
      assert Exception.message(error) == "Not enough plutonium!"
    end

    test "when a step returns an error and can be compensated and the compensation says it can continue it returns an ok tuple",
         %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Compensable)
      step = reactor.steps |> hd()

      Example.Step.Compensable
      |> stub(:run, fn _, _, _ -> {:error, :doc} end)
      |> stub(:compensate, fn :doc, _, _, _ -> {:continue, :marty} end)

      assert {:ok, :marty} = run(reactor, step)
    end

    test "when a step returns an error and can be compensated and the compensation succeed it returns an error tuple",
         %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Compensable)
      step = reactor.steps |> hd()

      Example.Step.Compensable
      |> stub(:run, fn _, _, _ -> {:error, :doc} end)
      |> stub(:compensate, fn :doc, _, _, _ -> :ok end)

      assert {:error, :doc} = run(reactor, step)
    end
  end

  describe "undo/3" do
    test "it calls undo on the step with the correct arguments", %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn value, arguments, _, _ ->
        assert value == :marty
        assert Enum.empty?(arguments)
        :ok
      end)

      undo(reactor, step, :marty)
    end

    test "when the step can be undone it returns ok", %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn _, _, _, _ -> :ok end)

      assert :ok = undo(reactor, step, :marty)
    end

    test "when the step undo needs to be retried it eventually returns ok", %{reactor: reactor} do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn _, _, _, _ -> :retry end)
      |> expect(:undo, fn _, _, _, _ -> :retry end)
      |> expect(:undo, fn _, _, _, _ -> :retry end)
      |> expect(:undo, fn _, _, _, _ -> :ok end)

      assert :ok = undo(reactor, step, :marty)
    end

    test "when the step undo is stuck in a retry loop, it eventually returns an error", %{
      reactor: reactor
    } do
      {:ok, reactor} = Builder.add_step(reactor, :marty, Example.Step.Undoable)
      step = reactor.steps |> hd()

      Example.Step.Undoable
      |> stub(:undo, fn _, _, _, _ -> :retry end)

      assert {:error, message} = undo(reactor, step, :marty)
      assert message =~ "retried 5 times"
    end
  end
end
