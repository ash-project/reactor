defmodule Reactor.Error.Unknown.UnknownError do
  @moduledoc """
  An error used to wrap unknown errors.
  """

  use Reactor.Error, fields: [:error], class: :unknown

  @doc false
  @impl true
  def splode_message(error) do
    """
    # Unknown Error

    An unknown error occurred.

    ## `error`:

    #{describe_error(error.error)}
    """
  end
end
