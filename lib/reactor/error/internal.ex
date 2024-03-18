defmodule Reactor.Error.Internal do
  @moduledoc """
  The [Splode error class](e:splode:get-started-with-splode.html#error-classes)
  for Reactor-caused errors.
  """
  use Reactor.Error, fields: [:errors], class: :reactor

  @doc false
  @impl true
  def splode_message(%{errors: errors}) do
    Splode.ErrorClass.error_messages(errors)
  end
end
