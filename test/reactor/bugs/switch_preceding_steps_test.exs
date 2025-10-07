# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Bugs.SwitchPrecedingStepsTest do
  @moduledoc false
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  defmodule MooStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(_args, _context, _opts) do
      Logger.warning("MOO")
      {:ok, :moo}
    end
  end

  defmodule BooStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(args, _context, _opts) do
      Logger.warning("BOO")
      {:ok, !args.value}
    end
  end

  defmodule TruthyStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(_args, _context, _opts) do
      Logger.warning("TRUTHY")
      {:ok, :truthy}
    end
  end

  defmodule FalsyStep do
    @moduledoc false
    use Reactor.Step
    require Logger

    def run(_args, _context, _opts) do
      Logger.warning("FALSY")
      {:ok, :falsy}
    end
  end

  defmodule BugReactor do
    @moduledoc false
    use Reactor

    input :value

    step :moo, MooStep

    step :boo, BooStep do
      argument :value, input(:value)
    end

    switch :is_truthy? do
      on result(:boo)

      matches? &(&1 in [nil, false]) do
        step :falsy, FalsyStep
      end

      default do
        step :truthy, TruthyStep
      end
    end
  end

  test "steps preceding a switch only get executed once" do
    logs =
      [level: :warning, format: "$message\n", colors: [enabled: false]]
      |> capture_log(fn ->
        Reactor.run(BugReactor, %{value: true})
      end)
      |> String.split(~r/\n+/)
      |> Enum.reject(&(&1 == ""))
      |> Enum.frequencies()

    assert logs["MOO"] == 1
    assert logs["BOO"] == 1
    assert logs["FALSY"] == 1
  end

  describe "nested dependency resolution" do
    test "handles direct nested dependencies" do
      defmodule DirectNestedReactor do
        use Reactor

        step :first_step do
          run fn _, _ ->
            {:ok, %{nested_value: "hello", other: "world"}}
          end
        end

        step :second_step do
          argument :value, result(:first_step, :nested_value)

          run fn %{value: value}, _ ->
            {:ok, "processed: #{value}"}
          end
        end
      end

      assert {:ok, "processed: hello"} = Reactor.run(DirectNestedReactor)
    end

    test "handles multiple levels of nesting" do
      defmodule MultiLevelNestedReactor do
        use Reactor

        step :level_one do
          run fn _, _ ->
            {:ok, %{level_two: %{level_three: "deep_value"}}}
          end
        end

        step :consumer do
          argument :deep, result(:level_one, [:level_two, :level_three])

          run fn %{deep: deep}, _ ->
            {:ok, "found: #{deep}"}
          end
        end
      end

      assert {:ok, "found: deep_value"} = Reactor.run(MultiLevelNestedReactor)
    end

    test "handles mixed dependency types" do
      defmodule MixedDependencyReactor do
        use Reactor

        step :data_step do
          run fn _, _ ->
            {:ok, %{key: "value", count: 42}}
          end
        end

        step :simple_step do
          run fn _, _ ->
            {:ok, "simple"}
          end
        end

        step :mixed_consumer do
          argument :key_value, result(:data_step, :key)
          argument :simple_value, result(:simple_step)

          run fn %{key_value: key, simple_value: simple}, _ ->
            {:ok, "#{key}-#{simple}"}
          end
        end
      end

      assert {:ok, "value-simple"} = Reactor.run(MixedDependencyReactor)
    end

    test "handles steps inside around blocks accessing parent scope results via arguments" do
      defmodule AroundParentScopeReactor do
        use Reactor

        step :parent_step do
          run fn _, _ ->
            {:ok, %{parent_data: "from_parent", count: 42}}
          end
        end

        around :around_step, &__MODULE__.do_around/4 do
          argument :parent_value, result(:parent_step, :parent_data)

          step :inner_step do
            argument :parent_value, input(:parent_value)

            run fn %{parent_value: value}, _ ->
              {:ok, "inner processed: #{value}"}
            end
          end
        end

        def do_around(arguments, context, steps, callback) do
          callback.(arguments, context, steps)
        end
      end

      assert {:ok, %{inner_step: "inner processed: from_parent"}} =
               Reactor.run(AroundParentScopeReactor)
    end
  end
end
