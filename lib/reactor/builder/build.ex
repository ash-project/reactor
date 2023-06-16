defprotocol Reactor.Builder.Build do
  @moduledoc """
  A protocol which DSL entities should implement which allows them to be built
  into a Reactor struct.
  """

  @doc """
  Build an entity into a Reactor.
  """
  @spec build(t, Reactor.t()) :: {:ok, Reactor.t()} | {:error, any}
  def build(entity, reactor)
end
