defmodule ReactorTest do
  use ExUnit.Case
  doctest Reactor

  test "greets the world" do
    assert Reactor.hello() == :world
  end
end
