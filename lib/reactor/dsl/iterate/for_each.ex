defmodule Reactor.Dsl.Iterate.ForEach do
  @moduledoc """
  The `iterate.for_each` DSL entity struct.

  See `d:Reactor.iterate.for_each`.
  """

  defstruct __identifier__: nil,
            as: nil,
            source: nil

  alias Reactor.Dsl.Iterate.Source

  @type t :: %__MODULE__{
          __identifier__: any,
          as: nil | atom,
          source: nil | atom
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :for_each,
      describe: """
      Given an input which implements Elixir's `Enumerable` protocol use it as
      the source for the iteration.
      """,
      examples: [
        """
        for_each do
          source :numbers
          as: :number
        end
        """
      ],
      target: __MODULE__,
      schema: [
        as: [
          type: :atom,
          required: true,
          doc: "The name to use for each value in the element map."
        ],
        source: [
          type: :atom,
          required: true,
          doc: "The name of an argument provided to the parent `iterate` step."
        ]
      ]
    }

  @doc """
  Generates a default initialiser for an enumerable.
  """
  @spec generate_initialiser(atom) :: Source.initialiser()
  def generate_initialiser(source) do
    fn args ->
      case Map.fetch(args, source) do
        {:ok, value} -> {:ok, value}
        :error -> {:error, "Cannot iterate: `#{source}` not present in args."}
      end
    end
  end

  @doc """
  Generates a default generator for an enumerable.
  """
  @spec generate_generator(atom) :: Source.generator()
  def generate_generator(as) do
    fn enumerable ->
      case Enum.take(enumerable, 1) do
        [] -> {:halt, []}
        [value] -> {:cont, [%{as => value}], Stream.drop(enumerable, 1)}
      end
    end
  end
end
