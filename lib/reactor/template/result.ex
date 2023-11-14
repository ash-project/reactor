defmodule Reactor.Template.Result do
  @moduledoc """
  The `result` template.
  """

  defstruct name: nil, sub_path: []

  @type t :: %__MODULE__{name: atom, sub_path: Reactor.Template.sub_path()}
end
