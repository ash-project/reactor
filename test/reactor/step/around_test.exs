defmodule Reactor.Step.AroundTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Error.Invalid.MissingInputError, Step.Around, Step.ReturnAllArguments}

  setup do
    context = %{current_step: %{name: :marty}}
    steps = [Builder.new_step!(:example, ReturnAllArguments, arg: {:input, :arg})]
    options = [fun: &__MODULE__.mock_around_fun/4, steps: steps]

    {:ok, context: context, steps: steps, options: options}
  end

  describe "run/3" do
    test "when passed an fun function of incorrect arity, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, error} =
               Around.run(%{}, context, Keyword.put(options, :fun, &Function.identity/1))

      assert Exception.message(error) =~ ~r/to be a 4 arity function/i
    end

    test "when passed a fun mfa which refers to a non-existent function, it returns an error",
         %{context: context, options: options} do
      assert {:error, error} =
               Around.run(%{}, context, Keyword.put(options, :fun, {Marty, :marty, []}))

      assert Exception.message(error) =~ ~r/`Marty.marty\/4` to be exported/i
    end

    test "when passed steps which are not steps, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, error} = Around.run(%{}, context, Keyword.put(options, :steps, [:marty]))
      assert Exception.message(error) =~ ~r/a list of `Reactor.Step` structs/i
    end

    test "when not passed a required input, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error,
              %{
                errors: [
                  %MissingInputError{step: %{name: :example}, argument: %{source: %{name: :arg}}}
                ]
              }} = Around.run(%{}, context, options)
    end

    test "when the around function fails before calling the callback, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, :fail_before} =
               Around.run(%{arg: :marty, fail_before: true}, context, options)
    end

    test "when the around function fails after calling the callback, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, :fail_after} = Around.run(%{arg: :fail_after}, context, options)
    end

    test "when the inner steps are successful, the results are returned to the around function",
         %{context: context, options: options} do
      {:ok, %{inner_result: %{example: %{arg: :marty}}}} =
        Around.run(%{arg: :marty}, context, options)
    end
  end

  def mock_around_fun(arguments, _context, _steps, _callback) when arguments.fail_before == true,
    do: {:error, :fail_before}

  def mock_around_fun(arguments, context, steps, callback) do
    case callback.(arguments, context, steps) do
      {:ok, %{example: %{arg: :fail_after}}} ->
        {:error, :fail_after}

      {:ok, result} ->
        {:ok, %{inner_result: result}}

      other ->
        other
    end
  end
end
