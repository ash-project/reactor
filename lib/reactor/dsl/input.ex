defmodule Reactor.Dsl.Input do
  @moduledoc """
  The struct used to store input DSL entities.
  """

  defstruct name: nil, transform: nil, __identifier__: nil
  alias Reactor.{Builder, Dsl}

  @type t :: %Dsl.Input{name: any, transform: {module, keyword}, __identifier__: any}

  defimpl Builder.Build do
    def build(input, reactor) do
      Builder.add_input(reactor, input.name, input.transform)
    end
  end
end
