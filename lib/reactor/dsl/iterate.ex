defmodule Reactor.Dsl.Iterate do
  @moduledoc """
  The `iterate` DSL entity struct.

  See `d:Reactor.iterate`.
  """
  defstruct __identifier__: nil,
            arguments: [],
            map: nil,
            name: nil,
            reduce: nil,
            source_from: nil,
            source: nil

  alias Reactor.{Builder, Dsl, Step}

  @type t :: %__MODULE__{
          __identifier__: any,
          arguments: [Dsl.Argument.t()],
          map: nil | __MODULE__.Map.t(),
          name: atom,
          reduce: nil | __MODULE__.Reduce.t(),
          source_from: nil | atom,
          source: nil | __MODULE__.Source.t()
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
        # Iterate over a string, reversing every word.

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
        """
      ],
      target: __MODULE__,
      args: [:name],
      identifier: :name,
      entities: [
        arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()],
        map: [__MODULE__.Map.__entity__()],
        reduce: [__MODULE__.Reduce.__entity__()],
        source: [__MODULE__.Source.__entity__()],
        steps: []
      ],
      imports: [Dsl.Argument],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "A unique name for this step."
        ],
        source_from: [
          type: :atom,
          required: false,
          doc: "Directly iterate a named argument."
        ]
      ]
    }

  defimpl Dsl.Build do
    import Reactor.Utils
    alias Spark.{Dsl.Transformer, Error.DslError}

    def build(map, reactor) do
      sub_reactor = Builder.new(reactor.id)

      with {:ok, sub_reactor} <- build_inputs(sub_reactor, map),
           {:ok, sub_reactor} <- build_steps(sub_reactor, map) do
        options =
          map
          |> Map.take([
            :accumulator,
            :finisher,
            :generator,
            :initialiser,
            :reducer,
            :return
          ])
          |> Map.put(:steps, sub_reactor.steps)
          |> Enum.to_list()

        Builder.add_step(reactor, map.name, {Step.Map, options}, map.arguments,
          async?: true,
          max_retries: 0,
          ref: :step_name
        )
      end
    end

    def verify(map, dsl_state) do
      module = Transformer.get_persisted(dsl_state, :module)

      with :ok <- validate_accumulator_and_reducer(map, module),
           :ok <- validate_steps_present(map, module) do
        validate_return_value(map, module)
      end
    end

    def transform(map, dsl_state) do
      with {:ok, map} <- maybe_set_return_value(map) do
        {:ok, Transformer.replace_entity(dsl_state, [:reactor], map)}
      end
    end

    defp maybe_set_return_value(map) when is_nil(map.return) do
      return =
        map.steps
        |> List.first(%{})
        |> Map.get(:name)

      {:ok, %{map | return: return}}
    end

    defp maybe_set_return_value(map), do: {:ok, map}

    defp validate_accumulator_and_reducer(map, module)
         when is_nil(map.accumulator) and not is_nil(map.reducer) do
      {:error,
       DslError.exception(
         module: module,
         path: [:reactor, :map, map.name],
         message: "When providing a `reducer` function you must specify the initial accumulator."
       )}
    end

    defp validate_accumulator_and_reducer(_, _), do: :ok

    defp validate_steps_present(map, module) when map.steps == [] do
      {:error,
       DslError.exception(
         module: module,
         path: [:reactor, :map, map.name],
         message: "Map steps must contain nested steps."
       )}
    end

    defp validate_steps_present(_, _), do: :ok

    defp validate_return_value(map, module) do
      if Enum.any?(map.steps, &(&1.name == map.return)) do
        :ok
      else
        {:error,
         DslError.exception(
           module: module,
           path: [:reactor, :map, map.name],
           message:
             "The cannot find a nested step named `#{inspect(map.return)}` to satisfy the provided return name."
         )}
      end
    end

    defp build_inputs(reactor, map) do
      map.arguments
      |> Enum.map(& &1.name)
      |> reduce_while_ok(reactor, &Builder.add_input(&2, &1))
    end

    defp build_steps(reactor, map) do
      map.steps
      |> reduce_while_ok(reactor, &Dsl.Build.build/2)
    end
  end
end
