defmodule Reactor.Error.Invalid.UndoRetriesExceededError do
  @moduledoc """
  An error used when a step runs out of retry events and no other error is
  thrown.
  """
  use Reactor.Error, fields: [:step, :retry_count], class: :invalid

  @doc false
  @impl true
  def splode_message(error) do
    """
    # Undo Retries Exceeded Error

    Maximum number of retries exceeded while attempting to undo step `#{inspect(error.step.name)}`.

    ## `retry_count`:

    #{inspect(error.retry_count)}

    ## `step`:

    #{inspect(error.step)}
    """
  end
end
