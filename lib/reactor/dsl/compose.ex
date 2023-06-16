defmodule Reactor.Dsl.Compose do
  @moduledoc """
  The `compose` DSL entity struct.

  See `Reactor.Dsl`.
  """
  defstruct arguments: [], name: nil, reactor: nil

  alias Reactor.{Builder, Dsl}

  @type t :: %Dsl.Compose{
          arguments: [Dsl.Argument.t()],
          name: any,
          reactor: module | Reactor.t()
        }

  defimpl Builder.Build do
    def build(compose, reactor) do
      Builder.compose(reactor, compose.name, compose.reactor, compose.arguments)
    end
  end
end
