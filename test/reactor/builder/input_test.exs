defmodule Reactor.Builder.InputTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Builder.Input, Step}

  describe "add_input/3" do
    test "when the input has no transform, it is added to the reactor" do
      assert {:ok, reactor} =
               Builder.new()
               |> Input.add_input(:marty, nil)

      assert :marty in reactor.inputs
      assert [] = reactor.steps
    end

    test "when the input has a transform function the input and a transform step are added to the reactor" do
      assert {:ok, reactor} =
               Builder.new()
               |> Input.add_input(:marty, &Function.identity/1)

      assert :marty in reactor.inputs
      assert [step] = reactor.steps

      assert step.name == {:__reactor__, :transform, :input, :marty}
      assert step.impl == {Step.Transform, fun: &Function.identity/1}
    end

    test "when the input has a transform impl the input and a transform step are added to the reactor" do
      assert {:ok, reactor} =
               Builder.new()
               |> Input.add_input(:marty, {Step.Transform, fun: &Function.identity/1})

      assert :marty in reactor.inputs
      assert [step] = reactor.steps

      assert step.name == {:__reactor__, :transform, :input, :marty}
      assert step.impl == {Step.Transform, fun: &Function.identity/1}
    end

    test "when the transform is not valid, it returns an error" do
      assert {:error, %Spark.Options.ValidationError{} = error} =
               Builder.new()
               |> Input.add_input(:marty, :doc)

      assert Exception.message(error) =~ ~r/expected :transform option/i
    end
  end
end
