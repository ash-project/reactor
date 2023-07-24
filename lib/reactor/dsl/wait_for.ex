defmodule Reactor.Dsl.WaitFor do
  @moduledoc """
  The struct used to store `wait_for` DSL entities.

  See `d:Reactor.step.wait_for`.
  """

  defstruct __identifier__: nil, names: []

  alias Reactor.{Argument, Dsl}
  import Reactor.Utils

  @type t :: %Dsl.WaitFor{names: [atom], __identifier__: any}

  defimpl Argument.Build do
    def build(wait_for) do
      wait_for
      |> Map.get(:names, [])
      |> map_while_ok(fn name ->
        {:ok, Argument.from_result(:_, name)}
      end)
    end
  end
end
