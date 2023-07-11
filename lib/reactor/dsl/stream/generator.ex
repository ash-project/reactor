defmodule Reactor.Dsl.Stream.Generator do
  @moduledoc """
  The struct used to store the `generator` DSL entity.

  See `d:Reactor.stream.generator`.
  """

  alias Reactor.{Dsl.Argument, Template}

  defstruct __identifier__: nil,
            arguments: [],
            run: nil,
            source: nil

  @type t :: %__MODULE__{
          __identifier__: any,
          arguments: [Argument.t()],
          source: nil | Template.Input.t() | Template.Result.t() | Template.Value.t(),
          run:
            nil | mfa | (Reactor.inputs() -> any) | (Reactor.inputs(), Reactor.context() -> any)
        }
end
