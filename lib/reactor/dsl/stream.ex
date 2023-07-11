defmodule Reactor.Dsl.Stream do
  @moduledoc """
  The struct used to store the `stream` DSL entity.

  See `d:Reactor.stream`.
  """

  alias Reactor.{Dsl.Stream, Template.Element}

  defstruct __identifier__: nil,
            generator: nil,
            name: nil,
            stages: []

  @type t :: %Stream{
          __identifier__: any,
          generator: Stream.Generator.t(),
          name: atom,
          stages: [stage]
        }

  @type stage :: Stream.Filter.t() | Stream.Reject.t()

  @doc """
  The `element` template helpers for the Reactor stream DSL.
  """
  @spec element(atom) :: Element.t()
  def element(stream_name), do: %Element{name: stream_name}
end
