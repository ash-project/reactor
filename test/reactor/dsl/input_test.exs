defmodule Reactor.Dsl.InputTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "reactors can have inputs" do
    defmodule InputReactor do
      @moduledoc false
      use Reactor

      input :input

      collect :result do
        argument :input, input(:input)
      end

      return :result
    end

    assert {:ok, %{input: "Marty McFly"}} = Reactor.run(InputReactor, %{input: "Marty McFly"})
  end

  test "reactor inputs can be transformed" do
    defmodule InputTransformReactor do
      @moduledoc false
      use Reactor

      input :input, transform: &String.upcase/1

      collect :result do
        argument :input, input(:input)
      end

      return :result
    end

    assert {:ok, %{input: "MARTY MCFLY"}} =
             Reactor.run(InputTransformReactor, %{input: "Marty McFly"})
  end

  test "reactor inputs can have descriptions" do
    defmodule InputDescriptionReactor do
      @moduledoc false
      use Reactor

      input :input, description: "An example input"

      collect :result do
        argument :input, input(:input)
      end

      return :result
    end

    reactor = Reactor.Info.to_struct!(InputDescriptionReactor)

    assert %{input: "An example input"} = reactor.input_descriptions
  end
end
