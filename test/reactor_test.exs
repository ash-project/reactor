defmodule ReactorTest do
  @moduledoc false
  use ExUnit.Case
  alias Example.{HelloWorldReactor, Step.Greeter}
  alias Reactor.{Builder, Info, Planner}

  doctest Reactor

  describe "run/1..4" do
    defmodule BasicReactor do
      @moduledoc false
      use Reactor

      input :name

      step :split do
        argument :name, input(:name)
        run(fn %{name: name}, _ -> {:ok, String.split(name)} end)
      end

      step :reverse do
        argument :chunks, result(:split)
        run(fn %{chunks: chunks}, _ -> {:ok, Enum.reverse(chunks)} end)
      end

      step :join do
        argument :chunks, result(:reverse)
        run(fn %{chunks: chunks}, _ -> {:ok, Enum.join(chunks, " ")} end)
      end
    end

    test "it can run a module-based reactor directly" do
      assert {:ok, "McFly Marty"} = Reactor.run(BasicReactor, name: "Marty McFly")
    end

    test "it can run unplanned reactors" do
      {:ok, reactor} = Info.to_struct(BasicReactor)

      assert {:ok, "McFly Marty"} = Reactor.run(reactor, name: "Marty McFly")
    end

    test "it can run partially planned reactors" do
      {:ok, reactor} = Info.to_struct(BasicReactor)
      join_step = Enum.find(reactor.steps, &(&1.name == :join))
      {:ok, reactor} = Planner.plan(reactor)

      reactor = %{
        reactor
        | plan: Graph.delete_vertex(reactor.plan, join_step),
          steps: [join_step]
      }

      assert {:ok, "McFly Marty"} = Reactor.run(reactor, name: "Marty McFly")
    end
  end
end
