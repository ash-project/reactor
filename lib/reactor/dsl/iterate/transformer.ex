defmodule Reactor.Dsl.Iterate.Transformer do
  @moduledoc false

  alias Reactor.Dsl.{Iterate, Iterate.ForEach, Iterate.Reduce, Iterate.Source}
  alias Spark.{Dsl, Dsl.Transformer, Error.DslError}

  @doc false
  @spec transform(Iterate.t(), Dsl.t()) :: :ok | {:error, DslError.t()}
  def transform(iterate, dsl_state) do
    with :ok <- verify_at_least_one_argument(iterate, dsl_state),
         :ok <- verify_source_or_for_each(iterate, dsl_state),
         :ok <- verify_map_and_or_reduce(iterate, dsl_state),
         {:ok, iterate} <- maybe_convert_for_each_into_source(iterate),
         {:ok, iterate} <- maybe_set_default_source_finaliser(iterate),
         {:ok, iterate} <- maybe_add_default_reducer(iterate),
         {:ok, iterate} <- maybe_set_default_reduce_finaliser(iterate) do
      dsl_state =
        dsl_state
        |> Transformer.replace_entity([:reactor], iterate)

      {:ok, dsl_state}
    end
  end

  defp verify_at_least_one_argument(iterate, dsl_state) when iterate.arguments == [] do
    {:error,
     DslError.exception(
       module: Transformer.get_persisted(dsl_state, :module),
       path: [:iterate],
       message: "Must provide at least one argument to iterate over."
     )}
  end

  defp verify_at_least_one_argument(_, _dsl_state), do: :ok

  defp verify_source_or_for_each(iterate, dsl_state)
       when is_nil(iterate.for_each) and is_nil(iterate.source) do
    {:error,
     DslError.exception(
       module: Transformer.get_persisted(dsl_state, :module),
       path: [:iterate],
       message: "Must provide either a `source` or `for_each` entity."
     )}
  end

  defp verify_source_or_for_each(iterate, _dsl_state)
       when is_nil(iterate.for_each),
       do: :ok

  defp verify_source_or_for_each(iterate, dsl_state)
       when is_nil(iterate.source),
       do: verify_for_each(iterate, dsl_state)

  defp verify_for_each(iterate, dsl_state) do
    argument_names = iterate.arguments |> Enum.map(& &1.name)

    if iterate.for_each.source in argument_names do
      :ok
    else
      {:error,
       DslError.exception(
         module: Transformer.get_persisted(dsl_state, :module),
         path: [:iterate, :for_each],
         message:
           "`for_each` refers to a source named `#{iterate.for_each.source}` but there is no argument with that name."
       )}
    end
  end

  defp verify_map_and_or_reduce(iterate, dsl_state)
       when is_nil(iterate.map) and is_nil(iterate.reduce) do
    {:error,
     DslError.exception(
       module: Transformer.get_persisted(dsl_state, :module),
       path: [:iterate],
       message: "Must provide a `map` and/or `reduce` entity."
     )}
  end

  defp verify_map_and_or_reduce(iterate, _dsl_state) when is_nil(iterate.map), do: :ok
  defp verify_map_and_or_reduce(iterate, dsl_state), do: verify_map(iterate.map, dsl_state)

  defp verify_map(map, dsl_state) do
    step_names =
      map.steps
      |> Enum.map(& &1.name)

    module = Transformer.get_persisted(dsl_state, :module)

    cond do
      step_names == [] ->
        {:error,
         DslError.exception(
           module: module,
           path: [:iterate, :map],
           message: "Must provide at least one step."
         )}

      is_nil(map.return) ->
        :ok

      map.return in step_names ->
        :ok

      true ->
        {:error,
         DslError.exception(
           module: module,
           path: [:iterate, :map],
           message: "Map return points to non-existant step named `#{map.return}`."
         )}
    end
  end

  defp maybe_convert_for_each_into_source(iterate) when is_nil(iterate.for_each),
    do: {:ok, iterate}

  defp maybe_convert_for_each_into_source(iterate) do
    source_name = iterate.for_each.source
    as_name = iterate.for_each.as

    source = %Source{
      finaliser: &ForEach.default_finaliser/1,
      initialiser: {ForEach, :default_initializer, [source_name]},
      generator: {ForEach, :default_generator, [as_name]}
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
