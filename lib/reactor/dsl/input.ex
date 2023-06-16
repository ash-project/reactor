defmodule Reactor.Dsl.Input do
  @moduledoc """
  The struct used to store input DSL entities.
  """

  defstruct __identifier__: nil,
            name: nil,
            transform: nil

  alias Reactor.{Builder, Dsl}

  @type t :: %Dsl.Input{name: any, transform: {module, keyword}, __identifier__: any}

  defimpl Dsl.Build do
    def build(input, reactor) do
      Builder.add_input(reactor, input.name, input.transform)
    end

    def transform(_input, dsl_state), do: {:ok, dsl_state}
    def verify(_input, _dsl_state), do: :ok
  end
end
