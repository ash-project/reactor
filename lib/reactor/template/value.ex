defmodule Reactor.Template.Value do
  @moduledoc """
  A statically `value` template.
  """

  defstruct value: nil

  @type t :: %__MODULE__{value: any}
end
