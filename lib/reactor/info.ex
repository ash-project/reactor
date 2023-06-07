defmodule Reactor.Info do
  @moduledoc """
  Introspection for the Reactor DSL.
  """
  use Spark.InfoGenerator, sections: [:reactor], extension: Reactor.Dsl

  alias Reactor.{Builder, Input, Step}

  @doc """
  Convert a reactor DSL module into a reactor struct.
  """
  @spec to_struct(module) :: {:ok, Reactor.t()} | {:error, any}
  def to_struct(module) when is_atom(module) do
    with :ok <- assert_is_reactor_module(module),
         {:ok, reactor} <- entities_to_struct(module) do
      maybe_set_return(module, reactor)
    end
  end

  defp entities_to_struct(module) do
    module
    |> reactor()
    |> Enum.reduce_while({:ok, Builder.new()}, fn
      input, {:ok, reactor} when is_struct(input, Input) ->
        case Builder.add_input(reactor, input.name, input.transform) do
          {:ok, reactor} -> {:cont, {:ok, reactor}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      step, {:ok, reactor} when is_struct(step, Step) ->
        case Builder.add_step(reactor, step.name, step.impl, step.arguments,
               async?: step.async?,
               max_retries: step.max_retries,
               transform: step.transform
             ) do
          {:ok, reactor} -> {:cont, {:ok, reactor}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  defp assert_is_reactor_module(reactor) when is_atom(reactor) do
    Code.ensure_loaded!(reactor)

    if reactor.spark_is() == Reactor do
      :ok
    else
      {:error, "Module `#{inspect(reactor)}` is not a valid Reactor module"}
    end
  rescue
    _error in [ArgumentError, UndefinedFunctionError] ->
      {:error, "Module `#{inspect(reactor)}` is not a valid Reactor module"}
  end

  defp maybe_set_return(module, reactor) do
    case reactor_return(module) do
      {:ok, value} -> {:ok, %{reactor | return: value}}
      :error -> {:ok, reactor}
    end
  end
end
