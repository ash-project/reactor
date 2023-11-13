defmodule Reactor.Dsl.Iterate do
  @moduledoc """
  The `iterate` DSL entity struct.

  See `d:Reactor.iterate`.
  """
  defstruct __identifier__: nil,
            arguments: [],
            async?: true,
            for_each: nil,
            map: nil,
            name: nil,
            reduce: nil,
            source: nil,
            steps: []

  alias Reactor.{Dsl, Dsl.Iterate}

  @type t :: %Iterate{
          __identifier__: any,
          arguments: [Dsl.Argument.t()],
          async?: boolean,
          for_each: nil | Iterate.ForEach.t(),
          map: nil | Iterate.Map.t(),
          name: atom,
          reduce: nil | Iterate.Reduce.t(),
          source: nil | Iterate.Source.t(),
          steps: []
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :iterate,
      describe: """
      Repeatedly execute a group of steps by emitting values from a generator
      and consolidate their results with a reducer.

      For more information about the semantics of the iterate step see the
      `Reactor.Step.Iterate` moduledocs.
      """,
      examples: [
        """
        # Iterate over a string, reversing every word using manual iteration.

        iterate :reverse_words do
          argument :words, input(:words)

          source do
            initialiser fn args ->
              {:ok, args.words}
            end

            generator fn words ->
              case String.split(words, ~r/\s+/, parts: 2, trim: true) do
                [] -> {:halt, ""}
                [word] -> {:cont, [%{word: word}], ""}
                [word, remaining] -> {:cont, [%{word: word}], remaining}
              end
            end
          end

          map do
            step :reverse_word do
              argument :word, element(:word)

              run fn %{word: word} ->
                {:ok, String.reverse(word)}
              end
            end
          end

          reduce do
            accumulator fn ->
              {:ok, []}
            end

            reducer fn word, acc ->
              {:cont, [word | acc]}
            end

            finaliser fn words ->
              {:ok, Enum.reverse(words)}
            end
          end
        end
        """,
        """
        # Summing an enumerable.

        iterate :sum do
          argument :numbers, input(:numbers)

          for_each do
            source :numbers
            as :number
          end

          reduce do
            accumulator value(0)
            reducer &{:ok, &1 + &2}
          end
        """
      ],
      target: Iterate,
      args: [:name],
      identifier: :name,
      entities: [
        arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()],
        for_each: [Iterate.ForEach.__entity__()],
        map: [Iterate.Map.__entity__()],
        reduce: [Iterate.Reduce.__entity__()],
        source: [Iterate.Source.__entity__()]
      ],
      singleton_entity_keys: [:for_each, :map, :reduce, :source],
      imports: [Dsl.Argument],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "A unique name for this step."
        ],
        async?: [
          type: :boolean,
          required: false,
          default: true,
          doc: "Allow the iteration to perform steps asynchronously."
        ]
      ]
    }

  defimpl Dsl.Build do
    defdelegate build(iterate, reactor), to: Iterate.Builder
    def verify(_iterate, _dsl_state), do: :ok
    defdelegate transform(iterate, dsl_state), to: Iterate.Transformer
  end
end
