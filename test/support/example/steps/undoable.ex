defmodule Example.Step.Undoable do
  @moduledoc false
  use Reactor.Step

  def run(_, _, _), do: {:ok, __MODULE__}

  def undo(_, _, _, _), do: :ok
end
