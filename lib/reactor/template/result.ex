defmodule Reactor.Template.Result do
  @moduledoc """
  The `result` template.
  """

  defstruct name: nil

  @type t :: %__MODULE__{name: atom}
end
