defprotocol Reactor.Dsl.Build do
  @moduledoc """
  A protocol which allows DSL entities to construct themselves into a Reactor.
  """

  @doc "Add the entity to the Reactor"
  @spec build(t, Reactor.t()) :: {:ok, Reactor.t()} | {:error, any}
  def build(entity, reactor)
end
