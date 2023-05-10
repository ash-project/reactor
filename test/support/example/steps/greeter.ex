defmodule Example.Step.Greeter do
  @moduledoc false
  use Reactor.Step

  def can?(_), do: false
  def run(%{whom: nil}, _, _), do: {:ok, "Hello, World!"}
  def run(%{whom: whom}, _, _), do: {:ok, "Hello, #{whom}!"}
end
