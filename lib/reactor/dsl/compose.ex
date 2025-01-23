defmodule Reactor.Dsl.Compose do
  @moduledoc """
  The `compose` DSL entity struct.

  See the `d:Reactor.compose`.
  """
  defstruct __identifier__: nil,
            arguments: [],
            description: nil,
            guards: [],
            name: nil,
            reactor: nil

  alias Reactor.{Builder, Dsl}

  @type t :: %Dsl.Compose{
          __identifier__: any,
          arguments: [Dsl.Argument.t()],
          description: nil | String.t(),
          guards: [Dsl.Where.t() | Dsl.Guard.t()],
          name: any,
          reactor: module | Reactor.t()
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :compose,
      describe: """
      Compose another Reactor into this one.

      Allows place another Reactor into this one as if it were a single step.
      """,
      args: [:name, :reactor],
      target: Dsl.Compose,
      identifier: :name,
      no_depend_modules: [:reactor],
      entities: [
        arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()],
        guards: [Dsl.Where.__entity__(), Dsl.Guard.__entity__()]
      ],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for the step. Allows the result of the composed reactor to be depended upon by steps in this reactor.
          """
        ],
        description: [
          type: :string,
          required: false,
          doc: """
          An optional description for the step.
          """
        ],
        reactor: [
          type: {:or, [{:struct, Reactor}, {:spark, Reactor.Dsl}]},
          required: true,
          doc: """
          The reactor module or struct to compose upon.
          """
        ]
      ]
    }

  defimpl Dsl.Build do
    def build(compose, reactor) do
      Builder.compose(reactor, compose.name, compose.reactor, compose.arguments,
        guards: compose.guards
      )
    end

    def transform(_compose, dsl_state), do: {:ok, dsl_state}
    def verify(_compose, _dsl_state), do: :ok
  end
end
