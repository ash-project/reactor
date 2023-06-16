defmodule Reactor.Step.AnonFnTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Step.AnonFn

  test "it is a step" do
    assert Spark.implements_behaviour?(Reactor.Step.AnonFn, Reactor.Step)
  end

  describe "run/3" do
    test "it can handle 2 arity anonymous functions" do
      fun = fn arguments, _ ->
        arguments.first_name
      end

      assert :marty = run(%{first_name: :marty}, %{}, run: fun)
    end

    test "it can handle an MFA" do
      assert :marty = run(%{first_name: :marty}, %{}, run: {__MODULE__, :example, []})
    end

    test "it rescues errors" do
      fun = fn _, _ -> raise "Marty" end

      assert {:error, error} = run(%{}, %{}, run: fun)
      assert Exception.message(error) =~ "Marty"
    end
  end

  def example(arguments, _context) do
    arguments.first_name
  end
end
