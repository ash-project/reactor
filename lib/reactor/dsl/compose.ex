defmodule Reactor.Dsl.Compose do
  @moduledoc """
  The `compose` DSL entity struct.

  See the `d:Reactor.compose`.
  """
  defstruct __identifier__: nil,
            arguments: [],
            async?: nil,
            description: nil,
            guards: [],
            name: nil,
            reactor: nil

  alias Reactor.{Builder, Dsl}

  @type t :: %Dsl.Compose{
          __identifier__: any,
          arguments: [Dsl.Argument.t() | Dsl.WaitFor.t()],
          async?: nil | boolean,
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
        ],
        async?: [
          type: :boolean,
          required: false,
          default: true,
          doc: """
          Whether the composed steps should be run asynchronously.
          """
        ]
      ]
    }

  defimpl Dsl.Build do
    alias Spark.{Dsl.Verifier, Error.DslError}

    def build(step, reactor) do
      Builder.compose(reactor, step.name, step.reactor, step.arguments,
        async?: step.async?,
        description: step.description,
        guards: step.guards
      )
    end

    def verify(step, dsl_state) do
      case Reactor.Builder.Compose.verify_arguments(step.reactor, step.arguments) do
        :ok ->
          :ok

        {:error, {:extra_args, inputs, extra_args}} ->
          {:error,
           %DslError{
             module: Verifier.get_persisted(dsl_state, :module),
             path: [:reactor, :step, step.name],
             message: """
             # Extra arguments while composing Reactors.

             The composed Reactor takes the following inputs:

             #{Enum.map_join(inputs, "\n", &"  - #{&1}")}

             The extra arguments are:

             #{Enum.map_join(extra_args, "\n", &"  - #{&1}")}
             """
           }}

        {:error, {:missing_args, inputs, missing_args}} ->
          {:error,
           %DslError{
             module: Verifier.get_persisted(dsl_state, :module),
             path: [:reactor, :step, step.name],
             message: """
             # Missing arguments while composing Reactors.

             The composed Reactor takes the following inputs:

             #{Enum.map_join(inputs, "\n", &"  - #{&1}")}

             The missing arguments are:

             #{Enum.map_join(missing_args, "\n", &"  - #{&1}")}
             """
           }}
      end
    end
  end
end
