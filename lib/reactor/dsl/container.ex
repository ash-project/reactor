defmodule Reactor.Dsl.Container do
  @moduledoc """
  The `container` DSL entity struct.

  See `Reactor.Dsl`.
  """
  defstruct steps: []
  alias Reactor.Step

  @type t :: %__MODULE__{steps: [Step.t()]}

  defimpl Reactor.Dsl.Build do
    def build(container, _reactor) do
      {:error, container}
    end
  end
end
