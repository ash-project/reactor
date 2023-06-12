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
end
