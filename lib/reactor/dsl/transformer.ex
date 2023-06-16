defmodule Reactor.Dsl.Transformer do
  @moduledoc false
  alias Reactor.{Dsl, Info, Planner}
  alias Spark.{Dsl.Transformer, Error.DslError}
  import Reactor.Utils
  use Transformer

  @doc false
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()} | {:error, DslError.t()}
  def transform(dsl_state) do
    with {:ok, step_names} <- step_names(dsl_state),
         {:ok, dsl_state} <- maybe_set_return(dsl_state, step_names),
         {:ok, dsl_state} <- validate_return(dsl_state, step_names),
         {:ok, dsl_state} <- do_entity_transform(dsl_state),
         {:ok, reactor} <- Info.to_struct(dsl_state),
         {:ok, reactor} <- Planner.plan(reactor) do
      dsl_state =
        dsl_state
        |> Transformer.eval(
          [reactor: Macro.escape(reactor)],
          quote do
            @doc false
            @spec reactor :: Reactor.t()
            def reactor, do: unquote(Macro.escape(reactor))
          end
        )

      {:ok, dsl_state}
    end
  end

  defp step_names(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:reactor])
    |> Enum.reject(&is_struct(&1, Dsl.Input))
    |> Enum.map(& &1.name)
    |> case do
      [] ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:reactor],
           message: "Reactor contains no steps"
         )}

      names ->
        names
        |> Enum.frequencies()
        |> reduce_while_ok(names, fn
          {_name, 1}, names -> {:ok, names}
          {name, n}, _names -> {:error, "There are #{n} steps named `#{inspect(name)}`."}
        end)
    end
  end

  defp do_entity_transform(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:reactor])
    |> reduce_while_ok(dsl_state, &Dsl.Build.transform/2)
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
