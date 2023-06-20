defmodule Reactor.Dsl.Step do
  @moduledoc """
  The struct used to store step DSL entities.
  """

  defstruct arguments: [],
            async?: true,
            compensate: nil,
            impl: nil,
            max_retries: :infinity,
            name: nil,
            run: nil,
            transform: nil,
            undo: nil,
            __identifier__: nil

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

  defimpl Builder.Build do
    def build(step, reactor) do
      Builder.add_step(reactor, step.name, step.impl, step.arguments,
        async?: step.async?,
        max_retries: step.max_retries,
        transform: step.transform,
        ref: :step_name
      )
    end
  end
end
