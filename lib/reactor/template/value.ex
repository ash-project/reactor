defmodule Reactor.Template.Value do
  @moduledoc """
  A statically `value` template.
  """

  defstruct value: nil, sub_path: []

  @type t :: %__MODULE__{value: any, sub_path: [any]}
end
