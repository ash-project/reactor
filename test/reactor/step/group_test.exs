defmodule Reactor.Step.GroupTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Error.Invalid.MissingInputError, Step.Group, Step.ReturnAllArguments}

  setup do
    context = %{current_step: %{name: :marty}}
    steps = [Builder.new_step!(:example, ReturnAllArguments, arg: {:input, :arg})]

    options = [
      before: &__MODULE__.mock_before_fun/3,
      after: &__MODULE__.mock_after_fun/1,
      steps: steps
    ]

    {:ok, context: context, steps: steps, options: options}
  end

  describe "run/3" do
    test "when passed a before function of incorrect arity, it returns an error", %{
      context: context
    } do
      assert {:error, error} = Group.run(%{}, context, before: &Function.identity/1)

      assert Exception.message(error) =~ ~r/to be a 3 arity function/i
    end

    test "when passed a before mfa that refers to a non-existent function, it returns an error",
         %{context: context, options: options} do
      assert {:error, error} =
               Group.run(%{}, context, Keyword.put(options, :before, {Marty, :marty, []}))

      assert error =~ ~r/Expected `Marty.marty\/3` to be exported/i
    end

    test "when passed an after function of incorrect arity, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, error} = Group.run(%{}, context, Keyword.put(options, :after, &Map.fetch/2))

      assert Exception.message(error) =~ ~r/to be a 1 arity function/
    end

    test "when passed an after mfa that refers to a non-existent function, it returns an error",
         %{context: context, options: options} do
      assert {:error, error} =
               Group.run(%{}, context, Keyword.put(options, :after, {Marty, :marty, []}))

      assert error =~ ~r/Expected `Marty.marty\/1` to be exported/i
    end

    test "when passed steps which are not steps, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, error} = Group.run(%{}, context, Keyword.put(options, :steps, [:marty]))

      assert Exception.message(error) =~ ~r/a list of `Reactor.Step` structs/i
    end

    test "when not passed a required input, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, %{errors: [%MissingInputError{argument: %{name: :arg}}]}} =
               Group.run(%{}, context, options)
    end

    test "when the before function fails, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, :before_failure} = Group.run(%{fail?: true}, context, options)
    end

    test "when the after function fails, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, :after_failure} = Group.run(%{arg: :fail}, context, options)
    end

    test "when the inner steps are successful, their results are passed to the after function", %{
      context: context,
      options: options
    } do
      assert {:ok, %{after_results: %{example: %{arg: :marty}}}} =
               Group.run(%{arg: :marty}, context, options)
    end
  end

  def mock_before_fun(arguments, context, steps) do
    if arguments[:fail?] do
      {:error, :before_failure}
    else
      {:ok, arguments, context, steps}
    end
  end

  def mock_after_fun(results) do
    if get_in(results, [:example, :arg]) == :fail do
      {:error, :after_failure}
    else
      {:ok, %{after_results: results}}
    end
  end
end
