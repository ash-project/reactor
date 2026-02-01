# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.StepTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Step}

  describe "can/2" do
    defp step_for_module(module), do: %Step{impl: module}

    test "when the step defines `undo/4`, it can undo" do
      assert Example.Step.Undoable
             |> step_for_module()
             |> Step.can?(:undo)
    end

    test "when the step does not define `undo/4`, it cannot undo" do
      refute Example.Step.Greeter
             |> step_for_module()
             |> Step.can?(:undo)
    end

    test "when the step defines `compensate/4`, it can compensate" do
      assert Example.Step.Compensable
             |> step_for_module()
             |> Step.can?(:compensate)
    end

    test "when the step does not defined `compensate/4`, it cannot compensate" do
      refute Example.Step.Greeter
             |> step_for_module()
             |> Step.can?(:compensate)
    end
  end

  describe "run/3" do
    test "it runs the step" do
      step = Builder.new_step!(:greet, Example.Step.Greeter, whom: {:input, :whom})

      assert {:ok, "Hello, Marty!"} = Step.run(step, %{whom: "Marty"}, %{})
    end
  end

  describe "compensate/4" do
    test "it runs the step's compensation callback" do
      step = Builder.new_step!(:compensate, Example.Step.Compensable)

      assert :ok = Step.compensate(step, "No plutonium", %{}, %{})
    end
  end

  describe "undo/4" do
    test "it runs the step's undo callback" do
      step = Builder.new_step!(:undo, Example.Step.Undoable)

      assert :ok = Step.undo(step, :marty, %{}, %{})
    end
  end

  describe "async?/1" do
    test "when the step is marked as async it returns true" do
      step = Builder.new_step!(:greet, Example.Step.Greeter, [], async?: true)

      assert Step.async?(step)
    end

    test "when the step is marked as sync it returns false" do
      step = Builder.new_step!(:greet, Example.Step.Greeter, [], async?: false)

      refute Step.async?(step)
    end

    test "when the step has options, they is passed to the async callback" do
      step =
        Builder.new_step!(:greet, {Example.Step.Greeter, [wat?: true]}, [],
          async?: fn opts -> opts[:wat?] end
        )

      assert Step.async?(step)
    end

    test "when the step has no options, an empty list is passed to the async callback" do
      step =
        Builder.new_step!(:greet, Example.Step.Greeter, [], async?: fn opts -> opts[:wat?] end)

      refute Step.async?(step)
    end
  end
end
