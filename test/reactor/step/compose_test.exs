defmodule Reactor.Step.ComposeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Argument, Executor.ConcurrencyTracker, Step}
  import Reactor.Builder
  require Reactor.Argument

  test "it is a step" do
    assert Spark.implements_behaviour?(Step.Compose, Step)
  end

  defmodule GreeterStep do
    @moduledoc false
    use Reactor.Step

    def run(%{whom: whom}, _, _) do
      {:ok, "Hello #{whom}"}
    end
  end

  describe "run/3" do
    test "when the composition would be recursive, it just runs the reactor directly" do
      inner_reactor =
        new()
        |> add_input!(:whom)
        |> add_step!(:greet, GreeterStep, whom: {:input, :whom})
        |> return!(:greet)

      assert {:ok, "Hello Marty McFly"} =
               Step.Compose.run(
                 %{whom: "Marty McFly"},
                 %{
                   current_step: %{name: :greet_marty},
                   concurrency_key: ConcurrencyTracker.allocate_pool(16),
                   private: %{composed_reactors: MapSet.new([inner_reactor.id])}
                 },
                 reactor: inner_reactor
               )
    end

    test "when the composition is not recursive, it emits rewritten steps" do
      inner_reactor =
        new()
        |> add_input!(:whom)
        |> add_step!(:greet, GreeterStep, whom: {:input, :whom})
        |> return!(:greet)

      assert {:ok, nil, new_steps} =
               Step.Compose.run(%{whom: "Marty McFly"}, %{current_step: %{name: :greet_marty}},
                 reactor: inner_reactor
               )

      new_steps_by_name = Map.new(new_steps, &{&1.name, &1})

      assert %Step{arguments: [argument], impl: impl} =
               Map.get(new_steps_by_name, {Step.Compose, :greet_marty, :greet})

      assert Argument.is_from_value(argument)
      assert argument.name == :whom
      assert argument.source.value == "Marty McFly"

      assert {Step.ComposeWrapper, [original: GreeterStep, prefix: [Step.Compose, :greet_marty]]} =
               impl

      assert %Step{arguments: [argument], impl: {Step.AnonFn, _}} =
               Map.get(new_steps_by_name, :greet_marty)

      assert Argument.is_from_result(argument)
      assert argument.name == :value
      assert argument.source.name == {Step.Compose, :greet_marty, :greet}
    end
  end
end
