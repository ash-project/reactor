defmodule Reactor.Error.Invalid.CompensateStepError do
  @moduledoc """
  This error is returned when an error occurs during step compensation.

  Its `error` key will contain the error that was raised or returned by the
  `c:Step.compensate/4` callback.
  """

  use Reactor.Error, fields: [:error, :reactor, :step], class: :invalid

  @doc false
  @impl true
  def splode_message(error) do
    """
    # Compensate Step Error

    An error occurred while attempting to compensate the `#{inspect(error.step.name)}` step.

    ## `step`:

    #{inspect(error.step)}

    ## `error`:

    #{describe_error(error.error)}
    """
  end
end
