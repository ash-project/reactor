defmodule Reactor.Dsl.Switch.Match do
  @moduledoc """
  The `matches?` DSL entity struct.

  See `d:Reactor.switch.matches?`.
  """

  defstruct __identifier__: nil,
            allow_async?: true,
            predicate: nil,
            return: nil,
            steps: []

  alias Reactor.Dsl.Step

  @type t :: %__MODULE__{
          __identifier__: any,
          allow_async?: boolean,
          predicate: (any -> any),
          return: nil | atom,
          steps: [Step.t()]
        }
end
