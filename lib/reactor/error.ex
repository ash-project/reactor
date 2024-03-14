defmodule Reactor.Error do
  @moduledoc """
  Uses `splode` to manage various classes of error.
  """

  use Splode,
    error_classes: [
      reactor: Reactor.Error.Internal,
      invalid: Reactor.Error.Invalid,
      unknown: Reactor.Error.Unknown,
      validation: Reactor.Error.Validation
    ],
    unknown_error: Reactor.Error.Unknown.UnknownError

  @doc "Convenience wrapper around `use Splode.Error`"
  @spec __using__(keyword) :: Macro.output()
  defmacro __using__(opts) do
    quote do
      use Splode.Error, unquote(opts)
      import Reactor.Error.Utils
      import Reactor.Utils
    end
  end
end
