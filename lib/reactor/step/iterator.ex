defmodule Reactor.Step.Iterator do
  @moduledoc """
  A special step which has the effect of iterating a stream of steps by
  repeatedly emitting new steps into the reactor until iteration is finished.
  """

  use Reactor.Step

  @doc false
  @spec run(Reactor.inputs(), Reactor.context(), Keyword.t()) ::
          {:ok, any, [Step.t()]} | {:error, any}
  def run(arguments, context, options) do
    {:ok, :wat, []}
  end
end
