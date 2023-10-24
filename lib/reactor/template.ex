defmodule Reactor.Template do
  @moduledoc """
  Templates used to refer to some sort of computed value.
  """

  alias __MODULE__.{Element, Input, Result, Value}

  @type t :: Element.t | Input.t() | Result.t() | Value.t()

  @doc "The type for use in option schemas"
  @spec type :: Spark.OptionsHelpers.type()
  def type, do: {:or, [{:struct, Element}, {:struct, Input}, {:struct, Result}, {:struct, Value}]}
end
