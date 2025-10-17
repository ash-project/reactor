defmodule Reactor.Input do
  @moduledoc """
  Reactor's internal representation for inputs.
  """
  defstruct [:name, :description]

  @type t :: %__MODULE__{
          name: atom,
          description: nil | String.t()
        }
end
