defmodule Reactor.Error.TransformError do
  defexception input: nil, output: nil, message: nil

  @impl true
  def exception(attrs), do: struct(__MODULE__, attrs)

  @impl true
  def message(error), do: error.message
end
