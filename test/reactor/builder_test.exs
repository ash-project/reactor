defmodule Reactor.BuilderTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Builder
  alias Reactor.{Step, Template}

  describe "new/0" do
    test "it returns an empty reactor struct" do
      assert is_struct(new(), Reactor)
    end
  end

  describe "add_input/2..3" do
    test "when the reactor argument is not a reactor struct, it returns an error" do
      assert {:error, error} = add_input(:reactor, :marty)
      assert Exception.message(error) =~ "not a Reactor"
    end

    test "when the input doesn't have a transformer, it adds the input step directly" do
      {:ok, reactor} = add_input(new(), :marty)
      assert :marty in reactor.inputs
      [step] = reactor.steps
      assert step.name == {:input, :marty}
      assert step.impl == {Step.Input, name: :marty}
    end

    test "when the input has a transformer it adds a transform step and an input step" do
      {:ok, reactor} = add_input(new(), :marty, &String.upcase/1)
      assert :marty in reactor.inputs
      [input_step, transform_step] = reactor.steps
      assert input_step.name == {:raw_input, :marty}
      assert input_step.impl == {Step.Input, name: :marty}

      assert transform_step.name == {:input, :marty}
      assert transform_step.impl == {Step.Transform, fun: &String.upcase/1}
      assert [argument] = transform_step.arguments
      assert argument.name == :input
      assert argument.source == %Template.Result{name: {:raw_input, :marty}}
    end
  end
end
