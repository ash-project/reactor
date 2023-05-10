defmodule Reactor.Input do
  @moduledoc """
  The struct used to store input DSL entities.
  """

  defstruct name: nil, transform: nil

  @type t :: %__MODULE__{name: any, transform: {module, keyword}}
end
