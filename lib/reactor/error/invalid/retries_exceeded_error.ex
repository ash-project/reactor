defmodule Reactor.Error.Invalid.RetriesExceededError do
  @moduledoc """
  This error is returned when a step attempts to retry more times that is
  allowed.
  """
  use Reactor.Error, fields: [:retry_count, :step], class: :invalid

  @doc false
  @impl true
  def splode_message(error) do
    """
    # Retries Exceeded Error

    Maximum number of retries exceeded executing step `#{inspect(error.step.name)}`.

    ## `retry_count`:

    #{inspect(error.retry_count)}

    ## `step`:

    #{inspect(error.step)}
    """
  end
end
