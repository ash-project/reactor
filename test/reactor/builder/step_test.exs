# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Builder.StepTest do
  @moduledoc false
  use ExUnit.Case, async: true
  require Reactor.Argument
  alias Reactor.{Argument, Builder, Step}

  defmodule GreeterStep do
    @moduledoc false
    use Reactor.Step

    def run(%{first_name: first_name, last_name: last_name}, _, _) do
      {:ok, "Hello #{first_name} #{last_name}"}
    end
  end

  describe "add_step/6" do
    test "when given an invalid argument it returns an error" do
      reactor = Builder.new()

      assert {:error, %ArgumentError{} = error} =
               Builder.Step.add_step(reactor, :greet, GreeterStep, [{:marty}], [])

      assert Exception.message(error) =~ ~r/non-argument/i
    end

    test "when the impl is not a `Reactor.Step` it returns an error" do
      reactor = Builder.new()

      assert {:error, %ArgumentError{} = error} =
               Builder.Step.add_step(reactor, :greet, Kernel, [], [])

      assert Exception.message(error) =~ ~r/does not implement the `Reactor.Step` behaviour/i
    end

    test "when the step depends on a transformed input, its arguments are rewritten" do
      reactor =
        Builder.new()
        |> Builder.add_input!(:first_name, &String.upcase/1)

      assert {:ok, reactor} =
               Builder.Step.add_step(
                 reactor,
                 :greet,
                 GreeterStep,
                 [first_name: {:input, :first_name}],
                 []
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})

      assert %Step{arguments: [argument]} = steps_by_name[:greet]
      assert argument.name == :first_name
      assert Argument.is_from_result(argument)
      assert argument.source.name == {:__reactor__, :transform, :input, :first_name}
    end

    test "when the step has argument transforms, it adds transformation steps" do
      transform = &Function.identity/1

      reactor =
        Builder.new()
        |> Builder.add_input!(:first_name)

      assert {:ok, reactor} =
               Builder.Step.add_step(
                 reactor,
                 :greet,
                 GreeterStep,
                 [Argument.from_input(:first_name, :first_name, transform)],
                 []
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})

      assert %Step{arguments: [argument]} = steps_by_name[:greet]
      assert argument.name == :first_name
      assert Argument.is_from_result(argument)
      assert argument.source.name == {:__reactor__, :transform, :first_name, :greet}

      assert %Step{arguments: [argument], impl: {Step.Transform, fun: ^transform}} =
               Map.get(steps_by_name, {:__reactor__, :transform, :first_name, :greet})

      assert Argument.is_from_input(argument)
      assert argument.source.name == :first_name
    end

    test "when the step has a transform, it adds a transform all step" do
      transform = &Function.identity/1

      reactor =
        Builder.new()
        |> Builder.add_input!(:first_name)

      assert {:ok, reactor} =
               Builder.Step.add_step(
                 reactor,
                 :greet,
                 GreeterStep,
                 [first_name: {:input, :first_name}],
                 transform: transform
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})

      assert %Step{arguments: [argument], context: context} = steps_by_name[:greet]
      assert :value = context.private.replace_arguments
      assert argument.name == :value
      assert Argument.is_from_result(argument)
      assert argument.source.name == {:__reactor__, :transform, :greet}

      assert %Step{
               arguments: [argument],
               impl: {Step.TransformAll, fun: ^transform}
             } = Map.get(steps_by_name, {:__reactor__, :transform, :greet})

      assert argument.name == :first_name
      assert Argument.is_from_input(argument)
      assert argument.source.name == :first_name
    end

    test "it defaults to an async step" do
      assert {:ok, reactor} =
               Builder.new()
               |> Builder.Step.add_step(
                 :greet,
                 GreeterStep,
                 [],
                 []
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})
      assert %Step{async?: true} = steps_by_name[:greet]
    end

    test "synchronous steps can be asked for" do
      assert {:ok, reactor} =
               Builder.new()
               |> Builder.Step.add_step(
                 :greet,
                 GreeterStep,
                 [],
                 async?: false
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})
      assert %Step{async?: false} = steps_by_name[:greet]
    end

    test "additional context can be provided" do
      assert {:ok, reactor} =
               Builder.new()
               |> Builder.Step.add_step(
                 :greet,
                 GreeterStep,
                 [],
                 context: %{awesome?: true}
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})
      assert %Step{context: %{awesome?: true}} = steps_by_name[:greet]
    end

    test "max retries defaults to 100" do
      assert {:ok, reactor} =
               Builder.new()
               |> Builder.Step.add_step(
                 :greet,
                 GreeterStep,
                 [],
                 []
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})
      assert %Step{max_retries: 100} = steps_by_name[:greet]
    end

    test "max retries can be provided" do
      assert {:ok, reactor} =
               Builder.new()
               |> Builder.Step.add_step(
                 :greet,
                 GreeterStep,
                 [],
                 max_retries: 99
               )

      steps_by_name = Map.new(reactor.steps, &{&1.name, &1})
      assert %Step{max_retries: 99} = steps_by_name[:greet]
    end
  end

  describe "new_step/5" do
    test "it builds a step" do
      assert {:ok, %Step{}} = Builder.Step.new_step(:marty, GreeterStep, [], [])
    end

    test "when given an invalid argument it returns an error" do
      assert {:error, error} = Builder.Step.new_step(:marty, GreeterStep, [{:doc}], [])
      assert Exception.message(error) =~ "non-argument"
    end

    test "when the impl is not a `Reactor.Step` it returns an error" do
      assert {:error, %ArgumentError{} = error} =
               Builder.Step.new_step(:greet, Kernel, [], [])

      assert Exception.message(error) =~ ~r/does not implement the `Reactor.Step` behaviour/i
    end

    test "when the step relies on transformed arguments, it returns an error" do
      assert {:error, %ArgumentError{} = error} =
               Builder.Step.new_step(
                 :greet,
                 GreeterStep,
                 [
                   Argument.from_input(:first_name, :name, &String.upcase/1)
                 ],
                 []
               )

      assert Exception.message(error) =~ ~r/has a transform attached/i
    end

    test "when the step wants a transform option, it returns an error" do
      assert {:error, %ArgumentError{} = error} =
               Builder.Step.new_step(
                 :greet,
                 GreeterStep,
                 [first_name: {:input, :first_name}],
                 transform: &Function.identity/1
               )

      assert Exception.message(error) =~ ~r/adding transforms to dynamic steps is not supported/i
    end
  end
end
