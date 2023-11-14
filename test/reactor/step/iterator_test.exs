defmodule Reactor.Step.IteratorTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Step.AnonFn, Step.Iterator}

  setup do
    context = %{current_step: %{name: :marty, async?: true}}

    options = [
      initialiser: &default_initialiser/2,
      generator: &default_generator/2,
      finaliser: &default_finaliser/2
    ]

    {:ok, context: context, options: options}
  end

  test "it is a step" do
    assert Spark.implements_behaviour?(Iterator, Reactor.Step)
  end

  describe "run/3" do
    test "when passed an incorrect state, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, error} =
               Iterator.run(%{}, context, Keyword.put(options, :iterator_state, :marty))

      assert Exception.message(error) =~ ~r/invalid state/i
    end

    test "when no state is set, it initialises correctly", %{context: context, options: options} do
      arguments = %{rand: 6 |> :crypto.strong_rand_bytes() |> Base.encode64()}

      options =
        options
        |> Keyword.put(:initialiser, fn args, con ->
          assert args == arguments
          assert con == context
          {:ok, :state_argument}
        end)

      assert {:ok, result, [recurse]} = Iterator.run(arguments, context, options)

      assert result == %{state: :state_argument}

      assert recurse.name == {:marty, 1}
      assert [argument] = recurse.arguments
      assert argument.name == :state
      assert is_struct(argument.source, Reactor.Template.Result)
      assert argument.source.name == :marty
      assert argument.source.sub_path == [:state]

      options = elem(recurse.impl, 1)

      # the default generator below generates no values
      assert options[:iterator_state] == :finalising

      assert options[:state_argument] == :state

      assert options[:elements] == 0
      assert options[:iterations] == 1
    end

    test "when generating, it returns numbered values", %{context: context, options: options} do
      context = put_in(context, [:current_step, :name], {:marty, 2})

      options =
        options
        |> Keyword.put(:iterator_state, :generating)
        |> Keyword.put(:iterations, 2)
        |> Keyword.put(:elements, 27)
        |> Keyword.put(:state_argument, :state)
        |> Keyword.put(:generator, fn acc ->
          {:cont, [acc * 2, (acc + 1) * 2], acc + 2}
        end)

      arguments = %{state: 123}

      assert {:ok, result, [recurse]} = Iterator.run(arguments, context, options)

      assert Map.get(result, {:element, 27}) == 246
      assert Map.get(result, {:element, 28}) == 248
      assert Map.get(result, :state) == 125

      assert recurse.name == {:marty, 3}
      assert [argument] = recurse.arguments
      assert argument.source.name == {:marty, 2}
      assert argument.source.sub_path == [:state]

      options = elem(recurse.impl, 1)

      assert options[:iterator_state] == :generating
      assert options[:elements] == 29
      assert options[:iterations] == 3
    end

    test "when the generator halts, it recurses one last time for the finaliser", %{
      context: context,
      options: options
    } do
      options =
        options
        |> Keyword.put(:iterator_state, :generating)
        |> Keyword.put(:state_argument, :state)
        |> Keyword.put(:generator, fn acc -> {:halt, acc} end)

      arguments = %{state: 123}

      assert {:ok, result, [recurse]} = Iterator.run(arguments, context, options)

      assert result == arguments

      assert [argument] = recurse.arguments
      assert argument.source.name == :marty
      assert argument.source.sub_path == [:state]

      options = elem(recurse.impl, 1)
      assert options[:iterator_state] == :finalising
    end

    test "when finalising the finaliser is run", %{context: context, options: options} do
      options =
        options
        |> Keyword.put(:iterator_state, :finalising)
        |> Keyword.put(:state_argument, :state)
        |> Keyword.put(:finaliser, fn acc ->
          assert acc == 123
          :ok
        end)

      assert {:ok, :ok} = Iterator.run(%{state: 123}, context, options)
    end
  end

  describe "integration" do
    defmodule Callbacks do
      @moduledoc false
      def initialiser(%{start: start}, _) do
        IO.puts("adding 10 to #{start}...")
        {:ok, {start, start + 10}}
      end

      def generator({current, finish}, _) when current == finish do
        {:halt, finish}
      end

      def generator({current, finish}, _) do
        {:cont, [current], {current + 1, finish}}
      end

      def step_generator(element_template, _) do
        {:ok,
         [
           Builder.new_step!(
             {:puts, element_template.name},
             {AnonFn, run: fn %{element: element} -> IO.puts(element) end},
             [element: element_template],
             []
           )
         ]}
      end

      def finaliser(finish, _) do
        IO.puts("finished at #{finish}")
        :ok
      end
    end

    defmodule IteratorReactor do
      @moduledoc false
      use Reactor

      input :start

      step :iterate,
           {Iterator,
            initialiser: &Callbacks.initialiser/2,
            generator: &Callbacks.generator/2,
            finaliser: &Callbacks.finaliser/2,
            step_generator: &Callbacks.step_generator/2} do
        argument :start, input(:start)
      end
    end

    test "it emits 10 values" do
      assert :wat = Reactor.run(IteratorReactor, %{start: 27})
    end
  end

  defp default_initialiser(arguments, _context), do: {:ok, Map.get(arguments, :init)}
  defp default_generator(acc, _context), do: {:halt, acc}
  defp default_finaliser(_acc, _context), do: :ok
end
