defmodule Reactor.Dsl.Switch.Default do
  @moduledoc """
  The `default` DSL entity struct.

  See `d:Reactor.switch.default`.
  """

  defstruct __identifier__: nil, return: nil, steps: []

  alias Reactor.Dsl

  @type t :: %__MODULE__{
          __identifier__: any,
          return: nil | atom,
          steps: [Dsl.Step.t()]
        }
end
