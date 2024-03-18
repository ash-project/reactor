defmodule Reactor.Error.Invalid.TransformError do
  @moduledoc """
  An error which occurs when building and running transforms.
  """
  use Reactor.Error, fields: [:input, :output, :error], class: :invalid

  @doc false
  @impl true
  def splode_message(error) do
    message = """
    # Transform Error

    An error occurred while trying to transform a value.

    ## `input`:

    `#{inspect(error.input)}`
    """

    message =
      if error.output do
        """
        #{message}

        ## `output`:

        `#{inspect(error.output)}`
        """
      else
        message
      end

    """
    #{message}

    ## `error`:

    #{describe_error(error.error)}
    """
  end
end
