defmodule Reactor.Dsl.ComposeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule InnerReactor do
    @moduledoc false
    use Reactor

    input :whom

    step :greet, Example.Step.Greeter do
      argument :whom, input(:whom)
    end

    return :greet
  end

  defmodule OuterReactor do
    @moduledoc false
    use Reactor

    compose :greet_john, InnerReactor do
      argument :whom, value("John")
    end

    compose :greet_paul, InnerReactor do
      argument :whom, value("Paul")
    end

    compose :greet_george, InnerReactor do
      argument :whom, value("George")
    end

    compose :greet_ringo, InnerReactor do
      argument :whom, value("Ringo")
    end

    collect :result do
      argument :john, result(:greet_john)
      argument :paul, result(:greet_paul)
      argument :george, result(:greet_george)
      argument :ringo, result(:greet_ringo)
    end
  end

  test "it composes the reactors" do
    assert {:ok, result} = Reactor.run(OuterReactor)
    assert result.john == "Hello, John!"
    assert result.paul == "Hello, Paul!"
    assert result.george == "Hello, George!"
    assert result.ringo == "Hello, Ringo!"
  end
end
