defmodule Reactor.ArgumentTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Argument, Template}
  doctest Argument

  describe "from_input/2..3" do
    test "when given no transformation it creates an argument" do
      assert %Argument{
               name: :argument_name,
               source: %Template.Input{name: :input_name},
               transform: nil
             } = Argument.from_input(:argument_name, :input_name)
    end

    test "when given a function transformation it creates an argument" do
      transform = &String.to_integer/1

      assert %Argument{
               name: :argument_name,
               source: %Template.Input{name: :input_name},
               transform: ^transform
             } = Argument.from_input(:argument_name, :input_name, transform)
    end

    test "when given an MFA transformation it creates an argument" do
      transform = {String, :to_integer, []}

      assert %Argument{
               name: :argument_name,
               source: %Template.Input{name: :input_name},
               transform: ^transform
             } = Argument.from_input(:argument_name, :input_name, transform)
    end
  end

  describe "from_result/2..3" do
    test "when given no transformation it creates an argument" do
      assert %Argument{
               name: :argument_name,
               source: %Template.Result{name: :step_name},
               transform: nil
             } = Argument.from_result(:argument_name, :step_name)
    end

    test "when given a function transformation it creates an argument" do
      transform = &Atom.to_string/1

      assert %Argument{
               name: :argument_name,
               source: %Template.Result{name: :step_name},
               transform: ^transform
             } = Argument.from_result(:argument_name, :step_name, transform)
    end

    test "when given an MFA transformation it creates an argument" do
      transform = {Atom, :to_string, []}

      assert %Argument{
               name: :argument_name,
               source: %Template.Result{name: :step_name},
               transform: ^transform
             } = Argument.from_result(:argument_name, :step_name, transform)
    end
  end

  describe "from_value/2" do
    test "when given no transformation it creates an argument" do
      assert %Argument{
               name: :argument_name,
               source: %Template.Value{value: 32},
               transform: nil
             } = Argument.from_value(:argument_name, 32)
    end

    test "when given a function transformation it creates an argument" do
      transform = &Atom.to_string/1

      assert %Argument{
               name: :argument_name,
               source: %Template.Value{value: 32},
               transform: ^transform
             } = Argument.from_value(:argument_name, 32, transform)
    end

    test "when given an MFA transformation it creates an argument" do
      transform = {Atom, :to_string, []}

      assert %Argument{
               name: :argument_name,
               source: %Template.Value{value: 32},
               transform: ^transform
             } = Argument.from_value(:argument_name, 32, transform)
    end
  end
end
