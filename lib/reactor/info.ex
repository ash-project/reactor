defmodule Reactor.Info do
  @moduledoc """
  Introspection for the Reactor DSL.
  """
  use Spark.InfoGenerator, sections: [:reactor], extension: Reactor.Dsl

  alias Reactor.{Builder, Dsl.Build}
  import Reactor.Utils

  @doc """
  Convert a reactor DSL module into a reactor struct.
  """
  @spec to_struct(module | Reactor.t() | Spark.Dsl.t()) :: {:ok, Reactor.t()} | {:error, any}
  def to_struct(reactor) when is_struct(reactor, Reactor), do: {:ok, reactor}

  def to_struct(module) do
    with {:ok, reactor} <- entities_to_struct(module) do
      maybe_set_return(module, reactor)
    end
  end

  @doc """
  Raising version of `to_struct/1`.
  """
  @spec to_struct!(module | Reactor.t() | Spark.Dsl.t()) :: Reactor.t() | no_return
  def to_struct!(reactor) do
    case to_struct(reactor) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  defp entities_to_struct(module) do
    module
    |> reactor()
    |> reduce_while_ok(Builder.new(module), &Build.build(&1, &2))
  end

  defp maybe_set_return(module, reactor) do
    case reactor_return(module) do
      {:ok, value} -> {:ok, %{reactor | return: value}}
      :error -> {:ok, reactor}
    end
  end
end
