defmodule Reactor.Dsl.Verifier do
  @moduledoc """
  Runs `Reactor.Dsl.Build.verify/2` for all the entities in the reactor.
  """
  use Spark.Dsl.Verifier
  alias Reactor.Dsl.Build
  alias Spark.Dsl.Verifier

  def verify(dsl_state) do
    dsl_state
    |> Verifier.get_entities([:reactor])
    |> Enum.reduce_while(:ok, fn entity, :ok ->
      case Build.verify(entity, dsl_state) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
