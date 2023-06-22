defmodule Reactor.Dsl.Compose do
  @moduledoc """
  The `compose` DSL entity struct.

  See the `Reactor` DSL docs.
  """
  defstruct arguments: [], name: nil, reactor: nil

  alias Reactor.{Builder, Dsl}

  @type t :: %Dsl.Compose{
          arguments: [Dsl.Argument.t()],
          name: any,
          reactor: module | Reactor.t()
        }

  defimpl Dsl.Build do
    def build(compose, reactor) do
      Builder.compose(reactor, compose.name, compose.reactor, compose.arguments)
    end

    def transform(_compose, dsl_state), do: {:ok, dsl_state}
    def verify(_compose, _dsl_state), do: :ok
  end
end
