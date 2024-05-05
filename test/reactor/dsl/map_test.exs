defmodule Reactor.Dsl.MapTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule MapReactor do
    @moduledoc false
    use Reactor

    input :numbers

    map :map_over_numbers do
      source(input(:numbers))
      batch_size(2)

      step :double do
        argument :input, element(:map_over_numbers)

        run fn %{input: input}, _ -> {:ok, input * 2} end
      end
    end
  end

  test "it maps over it's inputs" do
    numbers = [0, 2, 4, 6, 8, 10]

    assert {:ok, [0, 4, 8, 12, 16, 20]} =
             Reactor.run!(MapReactor, %{numbers: numbers}, %{}, async?: false)
  end
end
