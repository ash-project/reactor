defmodule Reactor.Step.AnonFnTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Step.AnonFn

  test "it is a step" do
    assert Spark.implements_behaviour?(Reactor.Step.AnonFn, Reactor.Step)
  end

  describe "run/2" do
    test "it can handle 2 arity anonymous functions" do
      fun = fn arguments, _ ->
        arguments.first_name
      end

      assert :marty = run(%{first_name: :marty}, %{}, run: fun)
    end

    test "it can handle an MFA" do
      assert :marty = run(%{first_name: :marty}, %{}, run: {__MODULE__, :example, []})
    end
  end

  def example(arguments, _context) do
    arguments.first_name
  end
end
