defmodule Reactor.Dsl.Iterate.Verifier do
  @moduledoc false

  alias Reactor.Dsl.Iterate
  alias Spark.{Dsl, Dsl.Transformer, Error.DslError}

  @doc false
  @spec verify(Iterate.t(), Dsl.t()) :: :ok | {:error, DslError.t()}
  def verify(iterate, dsl_state) do
    with :ok <- verify_at_least_one_argument(iterate, dsl_state),
         :ok <- verify_source_or_for_each(iterate, dsl_state) do
      verify_map_and_or_reduce(iterate, dsl_state)
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

  defp verify_source_or_for_each(_iterate, dsl_state) do
    {:error,
     DslError.exception(
       module: Transformer.get_persisted(dsl_state, :module),
       path: [:iterate],
       message: "Must provide either a `source` or `for_each` entity - not both."
     )}
  end

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
       message: "Must provide a `map` or `reduce` entity."
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
end
