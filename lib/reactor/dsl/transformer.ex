defmodule Reactor.Dsl.Transformer do
  @moduledoc false
  alias Reactor.{Dsl, Step}
  alias Spark.{Dsl.Transformer, Error.DslError}
  import Reactor.Utils
  use Transformer

  @doc false
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()} | {:error, DslError.t()}
  def transform(dsl_state) do
    with {:ok, dsl_state} <- rewrite_step_impls(dsl_state),
         {:ok, step_names} <- step_names(dsl_state),
         {:ok, dsl_state} <- maybe_set_return(dsl_state, step_names) do
      validate_return(dsl_state, step_names)
    end
  end

  defp step_names(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:reactor])
    |> Enum.filter(&(is_struct(&1, Dsl.Step) || is_struct(&1, Dsl.Compose)))
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

  defp rewrite_step_impls(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:reactor])
    |> Enum.filter(&is_struct(&1, Dsl.Step))
    |> reduce_while_ok(dsl_state, fn
      step, dsl_state when is_nil(step.impl) and is_nil(step.run) ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:reactor, :step, step.name],
           message: "Step has no implementation"
         )}

      step, dsl_state when not is_nil(step.impl) and not is_nil(step.run) ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:reactor, :step, step.name],
           message: "Step has both an implementation module and a run function"
         )}

      step, dsl_state when not is_nil(step.impl) and not is_nil(step.compensate) ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:reactor, :step, step.name],
           message: "Step has both an implementation module and a compensate function"
         )}

      step, dsl_state when not is_nil(step.impl) and not is_nil(step.undo) ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:reactor, :step, step.name],
           message: "Step has both an implementation module and a undo function"
         )}

      step, dsl_state
      when is_nil(step.run) and is_nil(step.compensate) and is_nil(step.undo) and
             not is_nil(step.impl) ->
        {:ok, dsl_state}

      step, dsl_state ->
        {:ok,
         Transformer.replace_entity(dsl_state, [:reactor], %{
           step
           | impl: {Step.AnonFn, run: step.run, compensate: step.compensate, undo: step.undo},
             run: nil,
             compensate: nil,
             undo: nil
         })}
    end)
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
