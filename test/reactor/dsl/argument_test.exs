defmodule Reactor.Dsl.ArgumentTest do
  @moduledoc false
  alias Reactor.Template
  import Reactor.Dsl.Argument
  use ExUnit.Case, async: true

  describe "input/1" do
    test "it creates an input template" do
      assert %Template.Input{name: :marty} = input(:marty)
    end
  end

  describe "result/1" do
    test "it creates an result template" do
      assert %Template.Result{name: :marty} = result(:marty)
    end
  end

  describe "value/1" do
    test "it creates a value template" do
      assert %Template.Value{value: :marty} = value(:marty)
    end
  end

  describe "Reactor.Argument.Build.build/1" do
    alias Reactor.{Argument, Dsl}

    test "it can build an argument" do
      transform = &Function.identity/1

      assert {:ok,
              [
                %Argument{
                  name: :name,
                  source: %Template.Input{name: :source},
                  transform: ^transform
                }
              ]} =
               Argument.Build.build(%Dsl.Argument{
                 name: :name,
                 source: %Template.Input{name: :source},
                 transform: transform,
                 __identifier__: :name
               })
    end
  end
end
