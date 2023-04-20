defmodule Reactor.Template do
  @moduledoc false
  alias Reactor.Template

  @typedoc """
  An input or result template.
  """
  @type t :: Template.Input.t() | Template.Result.t()
end
