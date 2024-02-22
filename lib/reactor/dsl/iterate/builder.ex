defmodule Reactor.Dsl.Iterate.Builder do
  @moduledoc false

  alias Reactor.{Builder, Step.Iterator}
  alias Reactor.Dsl.{Iterate, Iterate.ForEach, Iterate.Reduce, Iterate.Source}
  require ForEach

  @doc false
  @spec build(Iterate.t(), Reactor.t()) :: {:ok, Reactor.t()} | {:error, any}
  def build(iterate, reactor) do
    options =
      iterate
      |> Map.take([:map, :reduce, :source])
      |> Enum.reject(&is_nil(elem(&1, 1)))
      |> Enum.map(fn {key, struct} ->
        options =
          struct
          |> Map.from_struct()
          |> Enum.to_list()

        {key, options}
      end)

    Builder.add_step(reactor, iterate.name, {Iterator, options}, iterate.arguments,
      async?: iterate.async?,
      max_retries: 0,
      ref: :step_name
    )
  end
end
