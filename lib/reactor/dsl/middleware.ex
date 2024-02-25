defmodule Reactor.Dsl.Middleware do
  @moduledoc """
  The `middleware` DSL entity struct.

  See `d:Reactor.middleware.middleware`.
  """

  alias Reactor.{Dsl.Build, Middleware}

  defstruct __identifier__: nil, module: nil

  @type t :: %__MODULE__{
          __identifier__: any,
          module: Middleware.t()
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :middleware,
      describe: "Name a middleware to be added to the Reactor.",
      target: __MODULE__,
      args: [:module],
      identifier: :module,
      schema: [
        module: [
          type: {:behaviour, Middleware},
          required: true,
          doc: """
          The middleware to be added to the Reactor.
          """
        ]
      ]
    }

  defimpl Build do
    alias Reactor.Builder

    def build(middleware, reactor) do
      Builder.add_middleware(reactor, middleware.module)
    end

    def verify(_, _), do: :ok
    def transform(_, dsl_state), do: {:ok, dsl_state}
  end
end
