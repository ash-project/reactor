# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.MapTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule MapOverNumbersReactor do
    @moduledoc false
    use Reactor

    input :numbers

    step :multiplier do
      run fn _ -> {:ok, 2} end
    end

    map :map_over_numbers do
      source(input(:numbers))
      argument :multiplier, result(:multiplier)
      batch_size(2)

      step :double do
        argument :input, element(:map_over_numbers)

        run fn %{input: input, multiplier: multiplier}, _ ->
          {:ok, input * multiplier}
        end
      end
    end
  end

  test "it maps over it's inputs" do
    numbers = [0, 2, 4, 6, 8, 10]

    assert [0, 4, 8, 12, 16, 20] =
             Reactor.run!(MapOverNumbersReactor, %{numbers: numbers}, %{}, async?: false)
  end
end
