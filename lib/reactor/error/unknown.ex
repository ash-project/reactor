defmodule Reactor.Error.Unknown do
  @moduledoc """
  The [Splode error class](e:splode:get-started-with-splode.html#error-classes)
  for unknown errors.
  """

  use Reactor.Error, fields: [:errors], class: :unknown

  @doc false
  @impl true
  def message(%{errors: errors}) do
    Splode.ErrorClass.error_messages(errors)
  end
end
