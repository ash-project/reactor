defmodule Reactor.Builder.ArgumentTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Reactor.Builder.Argument
  alias Reactor.{Argument, Template}

  describe "asset_all_are_arguments/1" do
    test "when given an argument with an input tuple, it returns an input argument" do
      assert {:ok, [%Argument{name: :marty, source: %Template.Input{name: :doc}}]} =
               assert_all_are_arguments(marty: {:input, :doc})
    end

    test "when given an argument with an result tuple, it returns an result argument" do
      assert {:ok, [%Argument{name: :marty, source: %Template.Result{name: :doc}}]} =
               assert_all_are_arguments(marty: {:result, :doc})
    end

    test "when given an argument with a value, it returns a value argument" do
      assert {:ok, [%Argument{name: :marty, source: %Template.Value{value: :doc}}]} =
               assert_all_are_arguments(marty: :doc)
    end

    test "when given an argument struct, it returns the argument struct" do
      argument = Argument.from_value(:marty, :doc)

      assert {:ok, [^argument]} = assert_all_are_arguments([argument])
    end

    test "when given any other value, it returns an error" do
      assert {:error, error} = assert_all_are_arguments([:marty])

      assert Exception.message(error) =~ ~r/contains a non-argument value/
    end
  end
end
