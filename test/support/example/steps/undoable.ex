defmodule Example.Step.Undoable do
  @moduledoc false
  use Reactor.Step

  def can?(:undo), do: true
  def can?(_), do: false

  def run(_, _, _), do: {:ok, __MODULE__}
end
