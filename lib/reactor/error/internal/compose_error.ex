defmodule Reactor.Error.Internal.ComposeError do
  @moduledoc """
  This error is returned when two Reactors cannot be composed together.
  """

  use Reactor.Error,
    fields: [:arguments, :inner_reactor, :message, :outer_reactor],
    class: :reactor

  @doc false
  @impl true
  def splode_message(error) do
    [
      """
      # Reactor Compose Error

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
