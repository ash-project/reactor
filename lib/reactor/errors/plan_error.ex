defmodule Reactor.Error.PlanError do
  @moduledoc """
  An error thrown during the planning of a Reactor.
  """
  defexception [:reactor, :graph, :step, :message]
  import Reactor.Utils

  @doc false
  @impl true
  def exception(attrs), do: struct(__MODULE__, attrs)

  @doc false
  @impl true
  def message(error) do
    [
      """
      # Unable to plan Reactor

      #{error.message}
      """
    ]
    |> maybe_append_result(fn ->
      if error.reactor do
        """
        ## Reactor

        ```
        #{inspect(error.reactor)}
        ```
        """
      end
    end)
    |> maybe_append_result(fn ->
      if error.step do
        """
        ## Step

        ```
        #{inspect(error.step)}
        ```
        """
      end
    end)
    |> maybe_append_result(fn ->
      if error.graph do
        """
        ## Graph

        ```
        #{inspect(error.graph)}
        ```
        """
      end
    end)
    |> Enum.join("\n")
  end
end
