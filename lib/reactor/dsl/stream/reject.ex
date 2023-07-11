defmodule Reactor.Dsl.Stream.Reject do
  @moduledoc """
  The struct used to store the `reject` DSL entity.

  See `d:Reactor.stream.reject`.
  """

  alias Reactor.Dsl.Argument

  defstruct __identifier__: nil,
            arguments: [],
            predicate: nil

  @type t :: %__MODULE__{
          __identifier__: any,
          arguments: [Argument.t()],
          predicate:
            mfa | (Reactor.inputs() -> any) | (Reactor.inputs(), Reactor.context() -> any)
        }
end
