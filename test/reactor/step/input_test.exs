defmodule Reactor.Step.InputTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Step.Input

  test "it is a step" do
    assert Spark.implements_behaviour?(Reactor.Step.Input, Reactor.Step)
  end

  describe "run/3" do
    test "when the input is present in the private context it returns it" do
      assert {:ok, :marty} = run(%{}, %{private: %{inputs: %{name: :marty}}}, name: :name)
    end

    test "when the input is not present in the private context it returns an error" do
      assert {:error, error} = run(%{}, %{}, name: :name)
      assert Exception.message(error) =~ "missing an input"
    end

    test "when the name option is not present it returns an error" do
      assert {:error, error} = run(%{}, %{}, [])
      assert Exception.message(error) =~ "Missing `:name` option"
    end
  end
end
