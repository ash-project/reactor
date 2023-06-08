defmodule Reactor.BuilderTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Builder
  alias Reactor.{Argument, Step, Template}

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
      assert argument.name == :value
      assert argument.source == %Template.Result{name: {:raw_input, :marty}}
    end
  end

  describe "add_step/3..5" do
    defmodule Noop do
      @moduledoc false
      use Reactor.Step

      def run(_arguments, _context, _options), do: {:ok, :noop}
    end

    test "when the reactor argument is not a reactor struct, it returns an error" do
      assert {:error, error} = add_step(:reactor, :marty, Noop)
      assert Exception.message(error) =~ "not a Reactor"
    end

    test "when the implementation does not implement the Reactor.Step behaviour, it returns an error" do
      reactor = new()
      assert {:error, error} = add_step(reactor, :marty, __MODULE__)
      assert Exception.message(error) =~ "does not implement the `Reactor.Step` behaviour"
    end

    test "when the arguments option is not a list, it returns an error" do
      reactor = new()
      assert {:error, error} = add_step(reactor, :marty, Noop, :wat)
      assert Exception.message(error) =~ "is not a list"
    end

    test "when the options option is not a list, it returns an error" do
      reactor = new()
      assert {:error, error} = add_step(reactor, :marty, Noop, [], :wat)
      assert Exception.message(error) =~ "is not a list"
    end

    test "when an argument is an input tuple, it is converted to a argument struct in the step" do
      reactor = new()

      assert {:ok, %{steps: [step]}} = add_step(reactor, :marty, Noop, mentor: {:input, :doc})

      # this is a `result` not an `input` argument because it the input is
      # emitted as a separate step.
      assert [%Argument{name: :mentor, source: %Template.Result{name: {:input, :doc}}}] =
               step.arguments
    end

    test "when an argument is a result tuple, it is converted to a argument struct in the step" do
      reactor = new()

      assert {:ok, %{steps: [step]}} =
               add_step(reactor, :marty, Noop, mentor: {:result, :find_mentor})

      assert [%Argument{name: :mentor, source: %Template.Result{name: :find_mentor}}] =
               step.arguments
    end

    test "when an argument is an argument struct, it is added to the step" do
      reactor = new()

      assert {:ok, %{steps: [step]}} =
               add_step(reactor, :marty, Noop, [
                 %Argument{name: :mentor, source: %Template.Result{name: :find_mentor}}
               ])

      assert [%Argument{name: :mentor, source: %Template.Result{name: :find_mentor}}] =
               step.arguments
    end

    test "when an argument is anything else, it is an error" do
      reactor = new()
      assert {:error, error} = add_step(reactor, :marty, Noop, [:wat])
      assert Exception.message(error) =~ "is not a `Reactor.Argument` struct"
    end

    test "when an argument has a transformation function, it adds a transformation step to the reactor" do
      reactor = new()
      argument = Argument.from_result(:mentor, :find_mentor, &String.to_existing_atom/1)
      assert {:ok, reactor} = add_step(reactor, :marty, Noop, [argument])

      steps = Map.new(reactor.steps, &{&1.name, &1})

      assert %Step{
               arguments: [
                 %Argument{
                   name: :mentor,
                   source: %Template.Result{name: {:__reactor__, :transform, :mentor, :marty}}
                 }
               ]
             } = steps[:marty]

      assert %Step{
               arguments: [%Argument{name: :value, source: %Template.Result{name: :find_mentor}}],
               impl: {Step.Transform, [fun: _]}
             } = steps[{:__reactor__, :transform, :mentor, :marty}]
    end

    test "when the step has an argument transformation function, it adds the collect and transformation step to the reactor" do
      reactor = new()

      assert {:ok, reactor} =
               add_step(
                 reactor,
                 :add_user_to_org,
                 Noop,
                 [user: {:result, :create_user}, org: {:result, :create_org}],
                 transform: &%{user_id: &1.user.id, org_id: &1.org.id}
               )

      steps = Map.new(reactor.steps, &{&1.name, &1})

      assert %Step{
               arguments: [
                 %Argument{
                   name: :value,
                   source: %Template.Result{
                     name: {:__reactor__, :transform, :add_user_to_org}
                   }
                 }
               ]
             } = steps[:add_user_to_org]

      assert %Step{
               arguments: [
                 %Argument{name: :user, source: %Template.Result{name: :create_user}},
                 %Argument{name: :org, source: %Template.Result{name: :create_org}}
               ],
               impl: {Step.TransformAll, [fun: _]}
             } = steps[{:__reactor__, :transform, :add_user_to_org}]
    end
  end
end
