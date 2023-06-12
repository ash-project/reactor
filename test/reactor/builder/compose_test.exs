defmodule Reactor.Builder.ComposeTest do
  use ExUnit.Case, async: true
  alias Reactor.{Argument, Builder, Builder.Compose, Error.ComposeError, Planner, Step, Template}
  require Reactor.Argument

  describe "compose/4" do
    defmodule ShoutStep do
      @moduledoc false
      use Reactor.Step

      def run(%{message: message}, _, _) do
        {:ok, String.upcase(message)}
      end
    end

    defmodule InnerReactor do
      @moduledoc false
      use Reactor

      input :message

      step :shout, ShoutStep do
        argument :message, input(:message)
      end
    end

    test "when the inner reactor is a module and would be recursive, it adds a compose step" do
      assert {:ok, reactor} =
               InnerReactor
               |> Builder.new()
               |> Compose.compose(:recurse, InnerReactor, message: {:input, :message})

      assert recurse_step =
               reactor.steps
               |> Enum.find(&(&1.name == :recurse))

      assert {Step.Compose, [reactor: InnerReactor]} = recurse_step.impl

      assert [%Argument{name: :message, source: %Template.Input{name: :message}}] =
               recurse_step.arguments
    end

    test "when the inner reactor is a struct and would be recursive, it adds a compose step" do
      inner_reactor =
        Builder.new()
        |> Builder.add_input!(:message)
        |> Builder.add_step!(:shout, ShoutStep, message: {:input, :message})
        |> Builder.return!(:shout)

      assert {:ok, outer_reactor} =
               inner_reactor
               |> Builder.compose(:recurse, inner_reactor, message: {:input, :message})

      assert recurse_step =
               outer_reactor.steps
               |> Enum.find(&(&1.name == :recurse))

      assert {Step.Compose, [reactor: ^inner_reactor]} = recurse_step.impl

      assert [%Argument{name: :message, source: %Template.Input{name: :message}}] =
               recurse_step.arguments
    end

    test "when the inner reactor is already planned, steps are taken from the plan" do
      inner_reactor =
        Builder.new()
        |> Builder.add_input!(:message)
        |> Builder.add_step!(:shout, ShoutStep, message: {:input, :message})
        |> Builder.return!(:shout)
        |> Planner.plan!()

      assert [] = inner_reactor.steps
      assert is_struct(inner_reactor.plan, Graph)

      assert {:ok, outer_reactor} =
               Builder.new()
               |> Builder.add_input!(:name)
               |> Compose.compose(:shout_at, inner_reactor, message: {:input, :name})

      assert {:__reactor__, :compose, :shout_at, :shout} in Enum.map(
               outer_reactor.steps,
               & &1.name
             )
    end

    test "when the inner reactor is not already planned, steps are taken from the reactor" do
      inner_reactor =
        Builder.new()
        |> Builder.add_input!(:message)
        |> Builder.add_step!(:shout, ShoutStep, message: {:input, :message})
        |> Builder.return!(:shout)

      assert {:ok, outer_reactor} =
               Builder.new()
               |> Builder.add_input!(:name)
               |> Compose.compose(:shout_at, inner_reactor, message: {:input, :name})

      assert {:__reactor__, :compose, :shout_at, :shout} in Enum.map(
               outer_reactor.steps,
               & &1.name
             )
    end

    test "when the inner reactor does not have a return value, it returns an error" do
      inner_reactor =
        Builder.new()
        |> Builder.add_input!(:message)
        |> Builder.add_step!(:shout, ShoutStep, message: {:input, :message})

      assert {:error, %ComposeError{} = error} =
               Builder.new()
               |> Builder.add_input!(:name)
               |> Compose.compose(:shout_at, inner_reactor, message: {:input, :name})

      assert Exception.message(error) =~ ~r/must have an explicit return value/i
    end

    test "when provided an invalid argument, it returns an error" do
      inner_reactor =
        Builder.new()
        |> Builder.add_input!(:message)
        |> Builder.add_step!(:shout, ShoutStep, message: {:input, :message})

      assert {:error, %ArgumentError{} = error} =
               Builder.new()
               |> Builder.add_input!(:name)
               |> Compose.compose(:shout_at, inner_reactor, [:marty])

      assert Exception.message(error) =~ ~r/contains a non-argument value/i
    end

    test "when not all inner reactor inputs are covered by the provided arguments, it returns an error" do
      inner_reactor =
        Builder.new()
        |> Builder.add_input!(:message)
        |> Builder.add_step!(:shout, ShoutStep, message: {:input, :message})

      assert {:error, %ComposeError{} = error} =
               Builder.new()
               |> Builder.add_input!(:name)
               |> Compose.compose(:shout_at, inner_reactor, [])

      assert Exception.message(error) =~ ~r/missing argument for `message` input/i
    end

    test "inner steps are rewritten in the generated reactor" do
      {inner_reactor, outer_reactor} = multi_step_composed_reactor()

      steps_by_name = outer_reactor.steps |> Map.new(&{&1.name, &1})

      for step <- inner_reactor.steps do
        assert outer_step = Map.get(steps_by_name, {:__reactor__, :compose, :shout, step.name})
        outer_arguments_by_name = outer_step.arguments |> Map.new(&{&1.name, &1})

        for argument <- step.arguments do
          assert outer_argument = Map.get(outer_arguments_by_name, argument.name)

          if Argument.is_from_result(argument) do
            assert outer_argument.source.name ==
                     {:__reactor__, :compose, :shout, argument.source.name}
          end
        end
      end
    end

    test "a return step is generated" do
      {inner_reactor, outer_reactor} = multi_step_composed_reactor()

      steps_by_name = outer_reactor.steps |> Map.new(&{&1.name, &1})

      assert return_step = Map.get(steps_by_name, :shout)
      assert [return_value] = return_step.arguments
      assert Argument.is_from_result(return_value)
      assert return_value.name == :value
      assert return_value.source.name == {:__reactor__, :compose, :shout, inner_reactor.return}
    end

    test "the ID of the inner reactor is stored in the outer reactor context" do
      {inner_reactor, outer_reactor} = multi_step_composed_reactor()

      assert inner_reactor.id in Enum.to_list(outer_reactor.context.private.composed_reactors)
    end
  end

  defmodule GreeterStep do
    @moduledoc false
    use Reactor.Step

    def run(%{first_name: first_name, last_name: last_name}, _, _) do
      {:ok, "Hello #{first_name} #{last_name}"}
    end
  end

  defp multi_step_composed_reactor do
    shouty_reactor =
      Builder.new()
      |> Builder.add_input!(:first_name, &String.upcase/1)
      |> Builder.add_input!(:last_name, &String.upcase/1)
      |> Builder.add_step!(:greet, GreeterStep,
        first_name: {:input, :first_name},
        last_name: {:input, :last_name}
      )
      |> Builder.return!(:greet)

    composed_reactor =
      Builder.new()
      |> Builder.add_input!(:user)
      |> Builder.add_step!(:first_name, {Step.AnonFn, fun: &Map.fetch(&1.user, :first_name)},
        user: {:input, :user}
      )
      |> Builder.add_step!(:last_name, {Step.AnonFn, fun: &Map.fetch(&1.user, :last_name)},
        user: {:input, :user}
      )
      |> Builder.compose!(:shout, shouty_reactor,
        first_name: {:result, :first_name},
        last_name: {:result, :last_name}
      )
      |> Builder.return!(:shout)

    {shouty_reactor, composed_reactor}
  end
end
