defmodule Reactor.Error.Invalid.RunStepError do
  @moduledoc """
  This error is returned when an error occurs during step execution.

  Its `error` key will contain the error that was raised or returned by the
  `c:Step.run/3` callback.
  """
  use Reactor.Error, fields: [:error, :step], class: :invalid

  @doc false
  @impl true
  def message(error) do
    """
    # Run Step Error

    An error occurred while attempting to run the `#{inspect(error.step.name)}` step.

    ## `step`:

    #{inspect(error.step)}

    ## `error`:

    #{describe_error(error.error)}
    """
  end
end
