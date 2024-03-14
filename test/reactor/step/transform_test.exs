defmodule Reactor.Step.TransformTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Step.Transform

  test "it is a step" do
    assert Spark.implements_behaviour?(Reactor.Step.Transform, Reactor.Step)
  end

  describe "run/3" do
    test "when the value argument is missing" do
      assert {:error, error} = run(%{}, %{current_step: :current_step}, [])
      assert Exception.message(error) =~ "argument is missing"
    end

    test "it applies the transform" do
      assert {:ok, "marty"} = run(%{value: :marty}, %{}, fun: &Atom.to_string/1)
    end
  end
end
