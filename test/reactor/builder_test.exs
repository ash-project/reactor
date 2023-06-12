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

    test "when the input doesn't have a transformer, it adds the input" do
      {:ok, reactor} = add_input(new(), :marty)
      assert :marty in reactor.inputs
    end

    test "when the input has a transformer it adds a transform step and the input" do
      {:ok, reactor} = add_input(new(), :marty, &String.upcase/1)
      assert :marty in reactor.inputs
      [transform_step] = reactor.steps

      assert transform_step.name == {:__reactor__, :transform, :input, :marty}
      assert transform_step.impl == {Step.Transform, fun: &String.upcase/1}
      assert [argument] = transform_step.arguments
      assert argument.name == :value
      assert argument.source == %Template.Input{name: :marty}
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
      assert Exception.message(error) =~ "not a list"
    end

    test "when the options option is not a list, it returns an error" do
      reactor = new()
      assert {:error, error} = add_step(reactor, :marty, Noop, [], :wat)
      assert Exception.message(error) =~ "not a list"
    end

    test "when an argument is an input tuple, it is converted into an argument struct" do
      reactor = new()

      assert {:ok, %{steps: [step]}} = add_step(reactor, :marty, Noop, mentor: {:input, :doc})

      assert [
               %Argument{
                 name: :mentor,
                 source: %Template.Input{name: :doc}
               }
             ] = step.arguments
    end

    test "when an argument is a result tuple, it is converted to a argument struct" do
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
      assert Exception.message(error) =~ "contains a non-argument value"
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

    test "when the step has an argument transformation function, it adds a transformation step to the reactor" do
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

      assert %Step{arguments: arguments, impl: {Step.TransformAll, [fun: _]}} =
               steps[{:__reactor__, :transform, :add_user_to_org}]

      arguments = Enum.map(arguments, &{&1.name, &1.source.name})

      assert {:user, :create_user} in arguments
      assert {:org, :create_org} in arguments
    end
  end

  describe "compose/2" do
    defmodule GreeterStep do
      @moduledoc false
      use Reactor.Step

      def run(%{first_name: first_name, last_name: last_name}, _, _) do
        {:ok, "Hello #{first_name} #{last_name}"}
      end
    end

    test "when the reactor argument is not a reactor struct" do
      assert_raise ArgumentError, ~r/reactor.*not a Reactor/, fn ->
        compose!(:marty, :doc, new(), [])
      end
    end

    test "when the other reactor argument is not a reactor struct" do
      assert_raise ArgumentError, ~r/inner_reactor.*not a Reactor/, fn ->
        compose!(new(), :doc, 123, [])
      end
    end

    test "when the other arguments argument is not a list" do
      assert_raise ArgumentError, ~r/arguments.*not a list/, fn ->
        compose!(new(), :doc, new(), :marty)
      end
    end

    test "it can compose two reactors together" do
      shouty_reactor =
        new()
        |> add_input!(:first_name, &String.upcase/1)
        |> add_input!(:last_name, &String.upcase/1)
        |> add_step!(:greet, GreeterStep,
          first_name: {:input, :first_name},
          last_name: {:input, :last_name}
        )
        |> return!(:greet)

      composite_reactor =
        new()
        |> add_input!(:user)
        |> add_step!(:first_name, {Step.AnonFn, fun: &Map.fetch(&1.user, :first_name)},
          user: {:input, :user}
        )
        |> add_step!(:last_name, {Step.AnonFn, fun: &Map.fetch(&1.user, :last_name)},
          user: {:input, :user}
        )
        |> compose!(:shout, shouty_reactor,
          first_name: {:result, :first_name},
          last_name: {:result, :last_name}
        )
        |> return!(:shout)

      assert {:ok, "Hello MARTY MCFLY"} =
               Reactor.run(composite_reactor, %{user: %{first_name: "Marty", last_name: "McFly"}})
    end
  end
end
