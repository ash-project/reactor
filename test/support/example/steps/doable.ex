defmodule Example.Step.Doable do
  @moduledoc false
  use Reactor.Step

  def can?(_), do: false

  def run(_, _, _), do: {:ok, __MODULE__}
end
