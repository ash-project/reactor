defmodule Reactor.Error.ComposeError do
  @moduledoc """
  An error used when attempting to compose to Reactors together.
  """
  defexception [:outer_reactor, :inner_reactor, :message, :arguments]
  import Reactor.Utils

  @doc false
  @impl true
  def exception(attrs), do: struct(__MODULE__, attrs)

  @doc false
  @impl true
  def message(error) do
    [
      """
      # Unable to compose Reactors

      #{error.message}
      """
    ]
    |> maybe_append_result(fn ->
      if error.arguments do
        """
        ## Arguments

        ```
        #{inspect(error.arguments)}
        ```
        """
      end
    end)
    |> maybe_append_result(fn ->
      if error.inner_reactor do
        """
        ## Inner Reactor

        ```
        #{inspect(error.inner_reactor)}
        ```
        """
      end
    end)
    |> maybe_append_result(fn ->
      if error.outer_reactor do
        """
        ## Outer Reactor

        ```
        #{inspect(error.outer_reactor)}
        ```
        """
      end
    end)
    |> Enum.join("\n")
  end
end
