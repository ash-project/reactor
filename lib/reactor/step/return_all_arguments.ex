defmodule Reactor.Step.ReturnAllArguments do
  @moduledoc """
  A very simple step which simply returns all it's arguments unchanged.
  """

  use Reactor.Step

  @doc false
  @impl true
  def run(arguments, _, _), do: {:ok, arguments}
end
