defmodule Reactor.Template.Element do
  @moduledoc """
  The `element` template.
  """

  defstruct name: nil, sub_path: []

  @type t :: %__MODULE__{name: atom, sub_path: [atom]}
end
