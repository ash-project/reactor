defmodule Reactor.Info do
  @moduledoc """
  Introspection for the Reactor DSL.
  """
  use Spark.InfoGenerator, sections: [:reactor], extension: Reactor.Dsl

  alias Reactor.{Argument, Builder, Dsl}
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
    |> reduce_while_ok(Builder.new(module), fn
      input, reactor when is_struct(input, Dsl.Input) ->
        Builder.add_input(reactor, input.name, input.transform)

      step, reactor when is_struct(step, Dsl.Step) ->
        arguments =
          Enum.map(step.arguments, fn
            argument when is_struct(argument, Dsl.Argument) ->
              argument
              |> Map.from_struct()
              |> Map.take(~w[name source transform]a)
              |> then(&struct(Argument, &1))

            otherwise ->
              otherwise
          end)

        Builder.add_step(reactor, step.name, step.impl, arguments,
          async?: step.async?,
          max_retries: step.max_retries,
          transform: step.transform
        )

      compose, reactor when is_struct(compose, Dsl.Compose) ->
        Builder.compose(reactor, compose.name, compose.reactor, compose.arguments)
    end)
  end

  defp maybe_set_return(module, reactor) do
    case reactor_return(module) do
      {:ok, value} -> {:ok, %{reactor | return: value}}
      :error -> {:ok, reactor}
    end
  end
end
