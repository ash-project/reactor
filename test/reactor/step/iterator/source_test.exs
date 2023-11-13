defmodule Reactor.Step.Iterator.SourceTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Step.Iterator.Source}

  setup do
    context = %{current_step: %{name: :marty, async?: true}}

    options = [
      initialiser: &default_initialiser/2,
      generator: &default_generator/2,
      finaliser: &default_finaliser/2
    ]

    {:ok, context: context, options: options}
  end

  describe "run/3" do
    test "when passed an incorrect state, it returns an error", %{
      context: context,
      options: options
    } do
      assert {:error, error} = Source.run(%{}, context, Keyword.put(options, :state, :marty))

      assert Exception.message(error) =~ ~r/invalid state/i
    end

    test "when no state is set, it initialises correctly", %{context: context, options: options} do
      arguments = %{rand: 6 |> :crypto.strong_rand_bytes() |> Base.encode64()}

      options =
        options
        |> Keyword.put(:initialiser, fn args, con ->
          assert args == arguments
          assert con == context
          {:ok, :acc}
        end)

      assert {:ok, result, [recurse]} = Source.run(arguments, context, options)

      assert result == %{accumulator: :acc}

      assert recurse.name == {:marty, 1}
      assert [argument] = recurse.arguments
      assert argument.name == :accumulator
      assert is_struct(argument.source, Reactor.Template.Result)
      assert argument.source.name == :marty
      assert argument.source.sub_path == [:accumulator]

      options = elem(recurse.impl, 1)

      # the default generator below generates no values
      assert options[:state] == :finalising

      assert options[:acc] == :accumulator

      assert options[:elements] == 0
      assert options[:iterations] == 1
    end

    test "when generating, it returns numbered values", %{context: context, options: options} do
      context = put_in(context, [:current_step, :name], {:marty, 2})

      options =
        options
        |> Keyword.put(:state, :generating)
        |> Keyword.put(:iterations, 2)
        |> Keyword.put(:elements, 27)
        |> Keyword.put(:acc, :accumulator)
        |> Keyword.put(:generator, fn acc ->
          {:cont, [acc * 2, (acc + 1) * 2], acc + 2}
        end)

      arguments = %{accumulator: 123}

      assert {:ok, result, [recurse]} = Source.run(arguments, context, options)

      assert Map.get(result, {:element, 27}) == 246
      assert Map.get(result, {:element, 28}) == 248
      assert Map.get(result, :accumulator) == 125

      assert recurse.name == {:marty, 3}
      assert [argument] = recurse.arguments
      assert argument.source.name == {:marty, 2}
      assert argument.source.sub_path == [:accumulator]

      options = elem(recurse.impl, 1)

      assert options[:state] == :generating
      assert options[:elements] == 29
      assert options[:iterations] == 3
    end

    test "when the generator halts, it recurses one last time for the finaliser", %{
      context: context,
      options: options
    } do
      options =
        options
        |> Keyword.put(:state, :generating)
        |> Keyword.put(:acc, :accumulator)
        |> Keyword.put(:generator, fn acc -> {:halt, acc} end)

      arguments = %{accumulator: 123}

      assert {:ok, result, [recurse]} = Source.run(arguments, context, options)

      assert result == arguments

      assert [argument] = recurse.arguments
      assert argument.source.name == :marty
      assert argument.source.sub_path == [:accumulator]

      options = elem(recurse.impl, 1)
      assert options[:state] == :finalising
    end

    test "when finalising the finaliser is run", %{context: context, options: options} do
      options =
        options
        |> Keyword.put(:state, :finalising)
        |> Keyword.put(:acc, :accumulator)
        |> Keyword.put(:finaliser, fn acc ->
          assert acc == 123
          :ok
        end)

      assert {:ok, :ok} = Source.run(%{accumulator: 123}, context, options)
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

      def finaliser(finish, _) do
        IO.puts("finished at #{finish}")
        :ok
      end
    end

    defmodule SourceReactor do
      @moduledoc false
      use Reactor

      input :start

      step :iterate,
           {Source,
            initialiser: &Callbacks.initialiser/2,
            generator: &Callbacks.generator/2,
            finaliser: &Callbacks.finaliser/2} do
        argument :start, input(:start)
      end
    end

    test "it emits 10 values" do
      assert :wat = Reactor.run(SourceReactor, %{start: 27})
    end
  end

  defp default_initialiser(arguments, _context), do: {:ok, Map.get(arguments, :init)}
  defp default_generator(acc, _context), do: {:halt, acc}
  defp default_finaliser(_acc, _context), do: :ok
end
