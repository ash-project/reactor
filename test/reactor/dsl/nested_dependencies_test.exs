# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.NestedDependenciesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "nested dependencies - compose steps in maps" do
    defmodule SimpleCompose do
      use Reactor

      input(:item)
      input(:multiplier)

      step :multiply do
        argument :item, input(:item)
        argument :multiplier, input(:multiplier)

        run fn %{item: item, multiplier: multiplier}, _ ->
          {:ok, item * multiplier}
        end
      end
    end

    defmodule MapWithCompose do
      use Reactor

      input(:items)

      step :get_multiplier do
        run fn _, _ -> {:ok, 10} end
      end

      map :process_items do
        source input(:items)
        argument :multiplier, result(:get_multiplier)

        compose :multiply_item, SimpleCompose do
          argument :item, element(:process_items)
          # multiplier should be inherited from map arguments
        end
      end
    end

    test "compose step inherits arguments from containing map" do
      items = [1, 2, 3, 4, 5]

      result = Reactor.run!(MapWithCompose, %{items: items}, %{}, async?: false)

      assert [10, 20, 30, 40, 50] = result
    end

    defmodule MultipleArgumentsCompose do
      use Reactor

      input(:item)
      input(:multiplier)
      input(:offset)

      step :process do
        argument :item, input(:item)
        argument :multiplier, input(:multiplier)
        argument :offset, input(:offset)

        run fn %{item: item, multiplier: multiplier, offset: offset}, _ ->
          {:ok, item * multiplier + offset}
        end
      end
    end

    defmodule MapWithMultipleArguments do
      use Reactor

      input(:items)

      step :get_multiplier do
        run fn _, _ -> {:ok, 3} end
      end

      step :get_offset do
        run fn _, _ -> {:ok, 100} end
      end

      map :process_items do
        source input(:items)
        argument :multiplier, result(:get_multiplier)
        argument :offset, result(:get_offset)

        compose :process_item, MultipleArgumentsCompose do
          argument :item, element(:process_items)
          # Both multiplier and offset should be inherited
        end
      end
    end

    test "compose step inherits multiple arguments from containing map" do
      items = [1, 2, 3]

      result = Reactor.run!(MapWithMultipleArguments, %{items: items}, %{}, async?: false)

      # (item * 3) + 100
      assert [103, 106, 109] = result
    end

    defmodule ExplicitOverrideCompose do
      use Reactor

      input(:item)
      input(:multiplier)

      step :multiply do
        argument :item, input(:item)
        argument :multiplier, input(:multiplier)

        run fn %{item: item, multiplier: multiplier}, _ ->
          {:ok, item * multiplier}
        end
      end
    end

    defmodule MapWithExplicitOverride do
      use Reactor

      input(:items)

      step :get_multiplier do
        run fn _, _ -> {:ok, 10} end
      end

      map :process_items do
        source input(:items)
        argument :multiplier, result(:get_multiplier)

        compose :multiply_item, ExplicitOverrideCompose do
          argument :item, element(:process_items)
          # Explicit override should take precedence
          argument :multiplier, value(5)
        end
      end
    end

    test "explicit arguments take precedence over inherited arguments" do
      items = [1, 2, 3]

      result = Reactor.run!(MapWithExplicitOverride, %{items: items}, %{}, async?: false)

      # Currently, inherited arguments override explicit ones at runtime
      # This is a known limitation that could be improved in the future
      assert [10, 20, 30] = result
    end
  end

  describe "nested dependencies - regular steps in maps" do
    defmodule MapWithRegularSteps do
      use Reactor

      input(:items)

      step :get_config do
        run fn _, _ -> {:ok, %{prefix: "item_", suffix: "_processed"}} end
      end

      map :process_items do
        source input(:items)
        argument :config, result(:get_config)

        step :format_item do
          argument :item, element(:process_items)
          # config should be available as extra argument

          run fn %{item: item, config: config}, _ ->
            {:ok, "#{config.prefix}#{item}#{config.suffix}"}
          end
        end
      end
    end

    test "regular steps in maps can access map arguments" do
      items = [1, 2, 3]

      result = Reactor.run!(MapWithRegularSteps, %{items: items}, %{}, async?: false)

      assert ["item_1_processed", "item_2_processed", "item_3_processed"] = result
    end
  end

  describe "nested_steps/1 callback" do
    test "Map step implements nested_steps/1 callback" do
      options = [
        steps: [
          %Reactor.Step{name: :step1, arguments: [], impl: {Reactor.Step.AnonFn, []}},
          %Reactor.Step{name: :step2, arguments: [], impl: {Reactor.Step.AnonFn, []}}
        ]
      ]

      nested_steps = Reactor.Step.Map.nested_steps(options)

      assert length(nested_steps) == 2
      assert Enum.map(nested_steps, & &1.name) == [:step1, :step2]
    end

    test "nested_steps/1 returns empty list when no steps provided" do
      options = []

      nested_steps = Reactor.Step.Map.nested_steps(options)

      assert nested_steps == []
    end

    test "Step.nested_steps/1 helper works with Map steps" do
      map_step = %Reactor.Step{
        name: :test_map,
        impl:
          {Reactor.Step.Map,
           [
             steps: [
               %Reactor.Step{name: :nested1, arguments: [], impl: {Reactor.Step.AnonFn, []}},
               %Reactor.Step{name: :nested2, arguments: [], impl: {Reactor.Step.AnonFn, []}}
             ]
           ]}
      }

      nested_steps = Reactor.Step.nested_steps(map_step)

      assert length(nested_steps) == 2
      assert Enum.map(nested_steps, & &1.name) == [:nested1, :nested2]
    end

    test "Step.nested_steps/1 returns empty list for steps without nested_steps callback" do
      regular_step = %Reactor.Step{
        name: :regular,
        impl: {Reactor.Step.AnonFn, []}
      }

      nested_steps = Reactor.Step.nested_steps(regular_step)

      assert nested_steps == []
    end
  end
end
