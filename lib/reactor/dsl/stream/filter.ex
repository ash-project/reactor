defmodule Reactor.Dsl.Stream.Filter do
  @moduledoc """
  The struct used to store the `filter` DSL entity.

  See `d:Reactor.stream.filter`.
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
