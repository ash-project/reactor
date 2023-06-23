defmodule Reactor.Error.TransformError do
  @moduledoc """
  An error which occurs when building and running transforms.
  """
  defexception input: nil, output: nil, message: nil

  @doc false
  @impl true
  def exception(attrs), do: struct(__MODULE__, attrs)

  @doc false
  @impl true
  def message(error), do: error.message
end
