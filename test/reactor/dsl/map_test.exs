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

  defmodule MapWithStrictOrderingFalseReactor do
    @moduledoc false
    use Reactor

    input :numbers

    map :map_over_numbers do
      source(input(:numbers))
      strict_ordering?(false)

      step :double do
        argument :input, element(:map_over_numbers)

        run fn %{input: input}, _ ->
          {:ok, input * 2}
        end
      end
    end
  end

  describe "strict_ordering? option" do
    test "is passed through to the step" do
      {:ok, reactor_struct} = Reactor.Info.to_struct(MapWithStrictOrderingFalseReactor)

      map_step =
        Enum.find(reactor_struct.steps, fn step ->
          step.name == :map_over_numbers
        end)

      assert map_step != nil
      assert match?({Reactor.Step.Map, _opts}, map_step.impl)
      {_module, opts} = map_step.impl
      assert Keyword.get(opts, :strict_ordering?) == false
    end

    test "defaults to true when not specified" do
      {:ok, reactor_struct} = Reactor.Info.to_struct(MapOverNumbersReactor)

      map_step =
        Enum.find(reactor_struct.steps, fn step ->
          step.name == :map_over_numbers
        end)

      assert map_step != nil
      assert match?({Reactor.Step.Map, _opts}, map_step.impl)
      {_module, opts} = map_step.impl
      assert Keyword.get(opts, :strict_ordering?, true) == true
    end
  end
end
