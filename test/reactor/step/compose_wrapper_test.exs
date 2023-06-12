defmodule Reactor.Step.ComposeWrapperTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Reactor.{Builder, Step}

  test "it is a step" do
    assert Spark.implements_behaviour?(Step.ComposeWrapper, Step)
  end

  describe "run/3" do
    test "when the `original` option is missing, it returns an error" do
      assert {:error, error} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}}, prefix: [:a, :b])

      assert Exception.message(error) =~ ~r/missing/i
    end

    test "when the `original` option is a non-step module, it returns an error" do
      assert {:error, error} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}},
                 prefix: [:a, :b],
                 original: Kernel
               )

      assert Exception.message(error) =~ ~r/does not implement the `Reactor.Step` behaviour/i
    end

    test "when the `original` option refers to a non-step module, it returns an error" do
      assert {:error, error} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}},
                 prefix: [:a, :b],
                 original: {Kernel, []}
               )

      assert Exception.message(error) =~ ~r/does not implement the `Reactor.Step` behaviour/i
    end

    test "when the `prefix` option is an empty list, it returns an error" do
      assert {:error, error} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}},
                 prefix: [],
                 original: {Step.AnonFn, fun: fn args -> {:ok, args.a + 1} end}
               )

      assert Exception.message(error) =~ ~r/invalid `prefix` option/i
    end

    test "when the `prefix` option is not a list, it returns an error" do
      assert {:error, error} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}},
                 prefix: :marty,
                 original: {Step.AnonFn, fun: fn args -> {:ok, args.a + 1} end}
               )

      assert Exception.message(error) =~ ~r/invalid `prefix` option/i
    end

    test "when the original step returns an ok tuple, it returns it" do
      assert {:ok, 2} =
               Step.ComposeWrapper.run(%{a: 1}, %{current_step: %{name: :foo}},
                 prefix: [:a, :b],
                 original: {Step.AnonFn, fun: fn args -> {:ok, args.a + 1} end}
               )
    end

    test "when the original step returns an error tuple, it returns it" do
      assert {:error, :wat} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}},
                 prefix: [:a, :b],
                 original: {Step.AnonFn, fun: fn _ -> {:error, :wat} end}
               )
    end

    test "when the original step returns a halt tuple, it returns it" do
      assert {:halt, :wat} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}},
                 prefix: [:a, :b],
                 original: {Step.AnonFn, fun: fn _ -> {:halt, :wat} end}
               )
    end

    test "when the original step returns new dynamic steps, it rewrites them" do
      [new_c, new_d] = [
        Builder.new_step!(:c, {Step.AnonFn, fun: fn args -> {:ok, args.b} end}, b: {:input, :b}),
        Builder.new_step!(:d, {Step.AnonFn, fun: fn args -> {:ok, args.c + 1} end},
          c: {:result, :c}
        )
      ]

      assert {:ok, _, [rewritten_c, rewritten_d]} =
               Step.ComposeWrapper.run(%{}, %{current_step: %{name: :foo}},
                 prefix: [:a, :b],
                 original: {Step.AnonFn, fun: fn _ -> {:ok, nil, [new_c, new_d]} end}
               )

      assert rewritten_c.name == {:a, :b, new_c.name}
      assert [{rewritten_arg, new_arg}] = Enum.zip(rewritten_c.arguments, new_c.arguments)
      assert rewritten_arg.source.name == new_arg.source.name

      assert rewritten_d.name == {:a, :b, new_d.name}
      assert [{rewritten_arg, new_arg}] = Enum.zip(rewritten_d.arguments, new_d.arguments)
      assert rewritten_arg.source.name == {:a, :b, new_arg.source.name}
    end
  end
end
