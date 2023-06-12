defmodule Reactor.Dsl.Transformer do
  @moduledoc false
  alias Reactor.{Dsl.Compose, Step}
  alias Spark.{Dsl, Dsl.Transformer, Error.DslError}
  use Transformer

  @doc false
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()} | {:error, DslError.t()}
  def transform(dsl_state) do
    with {:ok, step_names} <- step_names(dsl_state),
         {:ok, dsl_state} <- maybe_set_return(dsl_state, step_names) do
      validate_return(dsl_state, step_names)
    end
  end

  defp step_names(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:reactor])
    |> Enum.filter(&(is_struct(&1, Step) || is_struct(&1, Compose)))
    |> Enum.map(& &1.name)
    |> case do
      [] ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:reactor],
           message: "Reactor contains no steps"
         )}

      step_names ->
        {:ok, step_names}
    end
  end

  defp maybe_set_return(dsl_state, step_names) do
    case Transformer.get_option(dsl_state, [:reactor], :return) do
      nil ->
        dsl_state =
          dsl_state
          |> Transformer.set_option([:reactor], :return, List.last(step_names))

        {:ok, dsl_state}

      _ ->
        {:ok, dsl_state}
    end
  end

  defp validate_return(dsl_state, step_names) do
    name = Transformer.get_option(dsl_state, [:reactor], :return)

    if name in step_names do
      {:ok, dsl_state}
    else
      {:error,
       DslError.exception(
         module: Transformer.get_persisted(dsl_state, :module),
         path: [:reactor],
         message: "Return value `#{inspect(name)}` does not correspond with an existing step"
       )}
    end
  end
end
