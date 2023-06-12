defmodule Reactor.Step.TransformAllTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.Step

  test "it is a step" do
    assert Spark.implements_behaviour?(Step.TransformAll, Step)
  end

  describe "run/3" do
    test "it applies the function to the `value` argument" do
      assert {:ok, %{a: 2}} =
               Step.TransformAll.run(%{a: 1}, %{}, fun: &Map.update(&1, :a, 1, fn v -> v * 2 end))
    end

    test "when the function returns a non-map value it returns an error" do
      assert {:error, error} = Step.TransformAll.run(%{a: 1}, %{}, fun: fn _ -> :wat end)
      assert Exception.message(error) =~ ~r/must return a map/i
    end

    test "when the function raises, it returns an error" do
      assert {:error, error} = Step.TransformAll.run(%{a: 1}, %{}, fun: fn _ -> raise "hell" end)
      assert Exception.message(error) == "hell"
    end
  end
end
