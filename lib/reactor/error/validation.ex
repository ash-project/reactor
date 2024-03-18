defmodule Reactor.Error.Validation do
  @moduledoc """
  The [Splode error class](e:splode:get-started-with-splode.html#error-classes)
  for validation errors.
  """

  use Reactor.Error, fields: [:errors], class: :validation

  @doc false
  @impl true
  def message(%{errors: errors}) do
    Splode.ErrorClass.error_messages(errors)
  end
end
