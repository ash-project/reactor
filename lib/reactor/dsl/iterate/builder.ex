defmodule Reactor.Dsl.Iterate.Builder do
  @moduledoc false

  alias Reactor.{Builder, Step.Iterator}
  alias Reactor.Dsl.{Iterate, Iterate.ForEach, Iterate.Reduce, Iterate.Source}
  require ForEach

  @doc false
  @spec build(Iterate.t(), Reactor.t()) :: {:ok, Reactor.t()} | {:error, any}
  def build(iterate, reactor) do
    with {:ok, iterate} <- maybe_convert_for_each_into_source(iterate),
         {:ok, iterate} <- maybe_set_default_source_finaliser(iterate),
         {:ok, iterate} <- maybe_add_default_reducer(iterate),
         {:ok, iterate} <- maybe_set_default_reduce_finaliser(iterate) do
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

  defp maybe_convert_for_each_into_source(iterate) when is_nil(iterate.for_each),
    do: {:ok, iterate}

  defp maybe_convert_for_each_into_source(iterate) do
    source_name = iterate.for_each.source
    as_name = iterate.for_each.as

    source = %Source{
      finaliser: &ForEach.default_finaliser/1,
      initialiser: ForEach.generate_initialiser(source_name),
      generator: ForEach.generate_generator(as_name)
    }

    {:ok, %{iterate | source: source, for_each: nil}}
  end

  defp maybe_set_default_source_finaliser(iterate) when is_nil(iterate.source.finaliser),
    do: {:ok, %{iterate | source: %{iterate.source | finaliser: &ForEach.default_finaliser/1}}}

  defp maybe_set_default_source_finaliser(iterate), do: {:ok, iterate}

  defp maybe_add_default_reducer(iterate) when is_nil(iterate.reduce) do
    reduce = %Reduce{
      accumulator: &Reduce.default_accumulator/0,
      finaliser: &Reduce.default_finaliser/1,
      reducer: &Reduce.default_reducer/2
    }

    {:ok, %{iterate | reduce: reduce}}
  end

  defp maybe_add_default_reducer(iterate), do: {:ok, iterate}

  defp maybe_set_default_reduce_finaliser(iterate) when is_nil(iterate.reduce.finaliser),
    do: {:ok, %{iterate | reduce: %{iterate.reduce | finaliser: &Reduce.default_finaliser/1}}}

  defp maybe_set_default_reduce_finaliser(iterate), do: {:ok, iterate}
end
