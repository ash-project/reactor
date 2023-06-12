defmodule Reactor.Dsl.PlanableVerifier do
  @moduledoc """
  Verifies that the Reactor is not cyclic.
  """

  use Spark.Dsl.Verifier
  alias Spark.{Dsl, Dsl.Verifier, Error.DslError}
  alias Reactor.{Info, Planner}

  @doc """
  Ensure that a DSL-based Reactor is not cyclic.
  """
  @impl true
  @spec verify(Dsl.t()) :: :ok | {:error, any}
  def verify(dsl_state) do
    with {:ok, reactor} <- Info.to_struct(dsl_state),
         {:ok, _} <- Planner.plan(reactor) do
      :ok
    else
      {:error, reason} when is_binary(reason) ->
        {:error,
         DslError.exception(
           module: Verifier.get_persisted(dsl_state, :module),
           path: [:reactor, :step],
           message: reason
         )}

      {:error, reason} when is_exception(reason) ->
        {:error, reason}
    end
  end
end
