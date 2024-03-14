defmodule Reactor.Error.Invalid.MissingInputError do
  @moduledoc """
  Error raised when a required Reactor input is missing.
  """

  use Reactor.Error, fields: [:argument, :reactor, :step], class: :invalid

  @doc false
  @impl true
  def splode_message(error) do
    inputs =
      error.reactor.inputs
      |> Enum.map_join("\n", &"  * `#{inspect(&1)}`")

    """
    # Missing Input Error

    The step `#{inspect(error.step.name)}` is expecting the Reactor to have an input named `#{inspect(error.argument.source.name)}` however it is not present.
    #{did_you_mean?(error.argument.source.name, error.reactor.inputs)}

    ## `step`:

    #{inspect(error.step)}

    ## `argument`:

    #{inspect(error.argument)}

    ## Available inputs:

    #{inputs}
    """
  end
end
