defmodule Reactor.Dsl.Transformer do
  @moduledoc false
  alias Reactor.Step
  alias Spark.{Dsl, Dsl.Transformer, Error.DslError}
  use Transformer

  @doc false
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()} | {:error, DslError.t()}
  def transform(dsl_state) do
    step_names =
      dsl_state
      |> Transformer.get_entities([:reactor])
      |> Enum.filter(&is_struct(&1, Step))
      |> Enum.map(& &1.name)

    case Transformer.get_option(dsl_state, [:reactor], :return) do
      nil ->
        dsl_state =
          dsl_state
          |> Transformer.set_option([:reactor], :return, List.last(step_names))

        {:ok, dsl_state}

      return_name ->
        if return_name in step_names do
          {:ok, dsl_state}
        else
          {:error,
           DslError.exception(
             module: Transformer.get_persisted(dsl_state, :module),
             path: [:reactor],
             message:
               "Return value `#{inspect(return_name)}` does not correspond with an existing step"
           )}
        end
    end
  end
end
