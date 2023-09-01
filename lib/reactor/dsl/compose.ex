defmodule Reactor.Dsl.Compose do
  @moduledoc """
  The `compose` DSL entity struct.

  See the `d:Reactor.compose`.
  """
  defstruct arguments: [], name: nil, reactor: nil

  alias Reactor.{Builder, Dsl}

  @type t :: %Dsl.Compose{
          arguments: [Dsl.Argument.t()],
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
      entities: [arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()]],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for the step.

          Allows the result of the composed reactor to be depended upon by steps
          in this reactor.
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
      Builder.compose(reactor, compose.name, compose.reactor, compose.arguments)
    end

    def transform(_compose, dsl_state), do: {:ok, dsl_state}
    def verify(_compose, _dsl_state), do: :ok
  end
end
