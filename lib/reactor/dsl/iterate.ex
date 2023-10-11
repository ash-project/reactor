defmodule Reactor.Dsl.Iterate do
  @moduledoc """
  The `iterate` DSL entity struct.

  See `d:Reactor.iterate`.
  """
  defstruct __identifier__: nil,
            arguments: [],
            for_each: nil,
            map: nil,
            name: nil,
            reduce: nil,
            source: nil,
            steps: []

  alias Reactor.{Builder, Dsl, Step}

  @type t :: %__MODULE__{
          __identifier__: any,
          arguments: [Dsl.Argument.t()],
          for_each: nil | __MODULE__.ForEach.t(),
          map: nil | __MODULE__.Map.t(),
          name: atom,
          reduce: nil | __MODULE__.Reduce.t(),
          source: nil | __MODULE__.Source.t(),
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
      target: __MODULE__,
      args: [:name],
      identifier: :name,
      entities: [
        arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()],
        for_each: [__MODULE__.ForEach.__entity__()],
        map: [__MODULE__.Map.__entity__()],
        reduce: [__MODULE__.Reduce.__entity__()],
        source: [__MODULE__.Source.__entity__()]
      ],
      singleton_entity_keys: [:for_each, :map, :reduce, :source],
      imports: [Dsl.Argument],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "A unique name for this step."
        ]
      ]
    }

  defimpl Dsl.Build do
    import Reactor.Utils
    alias Spark.{Dsl.Transformer, Error.DslError}

    def build(iterate, reactor) do
      {:ok, reactor}
    end

    def verify(iterate, dsl_state) do
      with :ok <- verify_source_or_for_each(iterate.source, iterate.for_each, dsl_state),
           :ok <- verify_map_and_or_reduce(iterate.map, iterate.reduce, dsl_state),
           :ok <- verify_at_least_one_argument(iterate.arguments, dsl_state),
           :ok <- verify_map(iterate.map, dsl_state),
           :ok <- verify_reduce(iterate.reduce, dsl_state),
           :ok <- verify_source(iterate.source, dsl_state) do
        :ok
      end
    end

    def transform(_map, dsl_state), do: {:ok, dsl_state}

    defp verify_source_or_for_each(nil, nil, dsl_state) do
      {:error,
       DslError.exception(
         module: Transformer.get_persisted(dsl_state, :module),
         path: [:iterate],
         message: "Must provide either a `source` or `for_each` entity."
       )}
    end

    defp verify_source_or_for_each(_source, nil, _dsl_state), do: :ok
    defp verify_source_or_for_each(nil, _from, _dsl_state), do: :ok

    defp verify_source_or_for_each(_source, _for_each, dsl_state) do
      {:error,
       DslError.exception(
         module: Transformer.get_persisted(dsl_state, :module),
         path: [:iterate],
         message: "Must provide either a `source` or `for_each` entity - not both."
       )}
    end

    defp verify_map_and_or_reduce(nil, nil, dsl_state) do
      {:error,
       DslError.exception(
         module: Transformer.get_persisted(dsl_state, :module),
         path: [:iterate],
         message: "Must provide a `map` or `reduce` entity."
       )}
    end

    defp verify_map_and_or_reduce(_map, _reduce, _dsl_state), do: :ok

    defp verify_at_least_one_argument([], dsl_state) do
      {:error,
       DslError.exception(
         module: Transformer.get_persisted(dsl_state, :module),
         path: [:iterate],
         message: "Must provide at least one argument to iterate over."
       )}
    end

    defp verify_at_least_one_argument(_, _dsl_state), do: :ok

    defp verify_map(nil, _dsl_state), do: :ok
    defp verify_map(map, _dsl_state) when map.return, do: :ok

    defp verify_map(map, dsl_state) do
      step_names =
        map.steps
        |> Enum.map(& &1.name)

      if map.return in step_names do
        :ok
      else
        # TODO WAT
      end
    end
  end
end
