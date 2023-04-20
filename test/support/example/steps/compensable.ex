defmodule Example.Step.Compensable do
  @moduledoc false
  use Reactor.Step

  def can?(:compensate), do: true
  def can?(_), do: false

  def run(_, _, _), do: {:ok, __MODULE__}
end
