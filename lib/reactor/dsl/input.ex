defmodule Reactor.Dsl.Input do
  @moduledoc """
  The struct used to store input DSL entities.
  """

  defstruct name: nil, transform: nil, __identifier__: nil

  @type t :: %__MODULE__{name: any, transform: {module, keyword}, __identifier__: any}
end
