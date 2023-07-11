defmodule Reactor.Template.Element do
  @moduledoc """
  The `element` template.
  """

  defstruct name: nil

  @type t :: %__MODULE__{name: atom}
end
