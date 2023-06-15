defmodule Reactor.Dsl.Compose do
  @moduledoc """
  The `compose` DSL entity struct.

  See `Reactor.Dsl`.
  """
  defstruct arguments: [], name: nil, reactor: nil

  @type t :: %__MODULE__{
          arguments: [Reactor.Argument.t()],
          name: any,
          reactor: module | Reactor.t()
        }

  defimpl Reactor.Dsl.Build do
    alias Reactor.Builder
    import Reactor, only: :macros

    def build(compose, reactor) when is_reactor(reactor) do
      Builder.compose(reactor, compose.name, compose.reactor, compose.arguments)
    end
  end
end
