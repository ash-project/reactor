defmodule Reactor.Dsl.Step do
  @moduledoc """
  The struct used to store step DSL entities.

  See `d:Reactor.step`.
  """

  defstruct __identifier__: nil,
            arguments: [],
            async?: true,
            compensate: nil,
            impl: nil,
            max_retries: :infinity,
            name: nil,
            run: nil,
            transform: nil,
            undo: nil

  alias Reactor.{Builder, Dsl}

  @type t :: %__MODULE__{
          arguments: [Dsl.Argument.t()],
          async?: boolean,
          compensate:
            nil | (any, Reactor.inputs(), Reactor.context() -> :ok | :retry | {:continue, any}),
          impl: module | {module, keyword},
          max_retries: non_neg_integer() | :infinity,
          name: atom,
          run:
            nil
            | (Reactor.inputs(), Reactor.context() ->
                 {:ok, any} | {:ok, any, [Reactor.Step.t()]} | {:halt | :error, any}),
          transform: nil | (any -> any),
          undo: nil | (any, Reactor.inputs(), Reactor.context() -> :ok | :retry | {:error, any}),
          __identifier__: any
        }

  defimpl Dsl.Build do
    alias Spark.Error.DslError

    def build(step, reactor) do
      with {:ok, step} <- rewrite_step(step, reactor.id) do
        Builder.add_step(reactor, step.name, step.impl, step.arguments,
          async?: step.async?,
          max_retries: step.max_retries,
          transform: step.transform,
          ref: :step_name
        )
      end
    end

    def transform(_step, dsl_state), do: {:ok, dsl_state}

    def verify(_step, _dsl_state), do: :ok

    defp rewrite_step(step, module) when is_nil(step.impl) and is_nil(step.run),
      do:
        {:error,
         DslError.exception(
           module: module,
           path: [:reactor, :step, step.name],
           message: "Step has no implementation"
         )}

    defp rewrite_step(step, module) when not is_nil(step.impl) and not is_nil(step.run),
      do:
        {:error,
         DslError.exception(
           module: module,
           path: [:reactor, :step, step.name],
           message: "Step has both an implementation module and a run function"
         )}

    defp rewrite_step(step, module)
         when not is_nil(step.impl) and not is_nil(step.compensate),
         do:
           {:error,
            DslError.exception(
              module: module,
              path: [:reactor, :step, step.name],
              message: "Step has both an implementation module and a compensate function"
            )}

    defp rewrite_step(step, module) when not is_nil(step.impl) and not is_nil(step.undo),
      do:
        {:error,
         DslError.exception(
           module: module,
           path: [:reactor, :step, step.name],
           message: "Step has both an implementation module and a undo function"
         )}

    defp rewrite_step(step, _dsl_state)
         when is_nil(step.run) and is_nil(step.compensate) and is_nil(step.undo) and
                not is_nil(step.impl),
         do: {:ok, step}

    defp rewrite_step(step, _dsl_state),
      do:
        {:ok,
         %{
           step
           | impl:
               {Reactor.Step.AnonFn, run: step.run, compensate: step.compensate, undo: step.undo},
             run: nil,
             compensate: nil,
             undo: nil
         }}
  end
end
