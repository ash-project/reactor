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

  @type t :: %__MODULE__{
          arguments: [Reactor.Argument.t()],
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
end
