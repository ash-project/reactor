defmodule Reactor.Error.Invalid.MissingArgumentError do
  @moduledoc """
  This error is returned when an expected argument is not passed to a step.
  """

  use Reactor.Error, fields: [:argument, :arguments, :step], class: :invalid

  @doc false
  @impl true
  def splode_message(error) do
    """
    # Missing Argument Error

    The step `#{inspect(error.step.name)}` run function is expecting to be passed the `#{inspect(error.argument)}` argument, but it is not present.
    #{did_you_mean?(error.argument, Map.keys(error.arguments))}

    ## `step`:

    #{inspect(error.step)}

    ## `argument`:

    #{inspect(error.argument)}

    ## Arguments passed:

    ```
    #{inspect(error.arguments)}
    ```
    """
  end
end
