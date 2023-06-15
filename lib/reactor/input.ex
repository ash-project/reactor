defmodule Reactor.Input do
  @moduledoc """
  The struct used to store input DSL entities.
  """

  defstruct name: nil, transform: nil

  @type t :: %__MODULE__{name: any, transform: {module, keyword}}

  defimpl Reactor.Dsl.Build do
    alias Reactor.Builder
    import Reactor, only: :macros

    def build(input, reactor) when is_reactor(reactor) do
      Builder.add_input(reactor, input.name, input.transform)
    end
  end
end
