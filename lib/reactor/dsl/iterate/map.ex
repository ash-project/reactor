defmodule Reactor.Dsl.Iterate.Map do
  @moduledoc """
  The `iterate.map` DSL entity struct.

  See `d:Reactor.iterate.map`.
  """

  defstruct __identifier__: nil,
            steps: [],
            return: nil

  alias Reactor.{Builder, Dsl, Step}

  @type t :: %__MODULE__{
          __identifier__: any,
          steps: [Dsl.Step.t()],
          return: nil | atom
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :map,
      describe: """
      The steps to run for each iteration.
      """,
      target: __MODULE__,
      identifier: {:auto, :unique_integer},
      entities: [
        steps: []
      ],
      schema: [
        return: [
          type: {:or, [nil, :atom]},
          required: false,
          doc: "Use result of the named step as the return value."
        ]
      ]
    }
end
