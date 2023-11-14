defmodule Reactor.Template.Input do
  @moduledoc """
  The `input` template.
  """

  defstruct name: nil, sub_path: []

  @type t :: %__MODULE__{name: atom, sub_path: Reactor.Template.sub_path()}
end
