defmodule Reactor.Step.SwitchTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Step.Switch}

  defmodule Noop do
    @moduledoc false
    use Reactor.Step

    def run(_, context, _), do: {:ok, context.current_step.name}
  end

  setup do
    context = %{current_step: %{name: :marty}}

    matches = [
      {&is_nil(&1), [Builder.new_step!(:is_nil, Noop, [])]},
      {&(&1 == false), [Builder.new_step!(:is_false, Noop, [])]}
    ]

    default = [Builder.new_step!(:is_other, Noop, [])]

    {:ok,
     context: context,
     matches: matches,
     default: default,
     options: [matches: matches, default: default, on: :value]}
  end

  describe "run/3" do
    test "when passed an `on` option which does not match an argument, it returns an error", %{
      context: context,
      matches: matches,
      default: default
    } do
      assert {:error, error} =
               Switch.run(%{}, context, matches: matches, default: default, on: :foo)

      assert Exception.message(error) =~ ~r/expected `on` option to match a provided argument/i
    end

    test "when passed no `matches` option, it returns an error", %{
      context: context,
      default: default
    } do
      assert {:error, error} = Switch.run(%{value: 1}, context, default: default, on: :value)
      assert Exception.message(error) =~ ~r/missing `matches` option/i
    end

    test "when passed `matches` which have invalid predicates, it returns an error", %{
      context: context,
      matches: matches
    } do
      matches =
        matches
        |> Enum.map(fn {_predicate, steps} ->
          {&Map.get/3, steps}
        end)

      assert {:error, error} = Switch.run(%{value: 1}, context, matches: matches, on: :value)
      assert Exception.message(error) =~ ~r/expected `predicate` to be a 1 arity function/i
    end

    test "when passed `matches` which have invalid steps, it returns an error", %{
      context: context,
      matches: matches
    } do
      matches =
        matches
        |> Enum.map(fn {predicate, _steps} ->
          {predicate, [URI.parse("http://example.com")]}
        end)

      assert {:error, error} = Switch.run(%{value: 1}, context, matches: matches, on: :value)
      assert Exception.message(error) =~ ~r/to be a `Reactor.Step` struct/i
    end

    test "when passed a `default` which contains invalid steps, it returns an error", %{
      context: context,
      matches: matches
    } do
      assert {:error, error} =
               Switch.run(%{value: 1}, context,
                 matches: matches,
                 default: [URI.parse("http://example.com")],
                 on: :value
               )

      assert Exception.message(error) =~ ~r/to be a `Reactor.Step` struct/i
    end

    test "it works", %{context: context, options: options} do
      assert {:ok, nil, [%{name: :is_nil}]} = Switch.run(%{value: nil}, context, options)
      assert {:ok, nil, [%{name: :is_false}]} = Switch.run(%{value: false}, context, options)
      assert {:ok, nil, [%{name: :is_other}]} = Switch.run(%{value: 13}, context, options)
    end

    test "when passed the `allow_async?` false option, it rewrites the returned steps", %{
      context: context,
      options: options
    } do
      assert {:ok, nil, [%{async?: false}]} =
               Switch.run(%{value: 13}, context, Keyword.put(options, :allow_async?, false))
    end

    test "when not passed a default and no matches are found, it returns an error", %{
      context: context,
      matches: matches
    } do
      assert {:error, error} = Switch.run(%{value: 13}, context, matches: matches, on: :value)

      assert error =~ ~r/no default branch/i
    end
  end
end
