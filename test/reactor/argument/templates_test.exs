defmodule Reactor.Argument.TemplatesTest do
  @moduledoc false
  alias Reactor.Template
  import Reactor.Argument.Templates
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
end
