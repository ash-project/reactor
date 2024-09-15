defmodule Reactor.Error.Invalid.ForcedFailureError do
  @moduledoc """
  This error is returned when the `flunk` DSL entity or the `Reactor.Step.Fail`
  step are called.
  """

  use Reactor.Error,
    fields: [:arguments, :step_name, :message, :context, :options],
    class: :invalid

  @type t :: %__MODULE__{
          __exception__: true,
          arguments: %{atom => any},
          step_name: any,
          message: String.t(),
          context: map,
          options: keyword
        }

  @doc false
  @impl true
  def message(error), do: error.message
end
