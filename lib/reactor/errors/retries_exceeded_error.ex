defmodule Reactor.Error.RetriesExceededError do
  @moduledoc """
  An error used when a step runs out of retry events and no other error is
  thrown.
  """
  defexception [:step, :retry_count]

  @doc false
  @impl true
  def exception(attrs), do: struct(__MODULE__, attrs)

  @doc false
  @impl true
  def message(error) do
    """
    # Maximum number of retries exceeded executing step.

    ## `retry_count`:

    #{inspect(error.retry_count)}

    ## `step`:

    #{inspect(error.step)}
    """
  end
end
