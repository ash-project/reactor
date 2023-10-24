defmodule Reactor.Dsl.Iterate.Reduce do
  @moduledoc """
  The `iterate.reduce` DSL entity struct.

  See `d:Reactor.iterate.reduce`.
  """

  defstruct __identifier__: nil,
            accumulator: nil,
            finaliser: nil,
            reducer: nil

  @type acc :: any
  @type element :: any
  @type accumulator ::
          (Reactor.inputs(), Reactor.context() -> {:ok, acc} | {:error, any})
          | (Reactor.inputs() -> {:ok, acc} | {:error, any})
          | (-> {:ok, acc} | {:error, any})
  @type finaliser ::
          (acc, Reactor.context() -> {:ok, any} | {:error, any})
          | (acc -> {:ok, any} | {:error, any})
  @type reducer ::
          (element, acc, Reactor.context() -> {:cont, acc} | {:halt, acc} | {:error, any})
          | (element, acc -> {:cont, acc} | {:halt, acc} | {:error, any})

  @type t :: %__MODULE__{
          __identifier__: any,
          accumulator: accumulator,
          finaliser: finaliser,
          reducer: reducer
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :reduce,
      describe: """
      Reduces the results into a single value.

      Similar in semantics to `Enum.reduce_while/3`, the `reduce` entity is
      responsible for collecting results into a single value which will be the
      result of the iterate step.

      ## Accumulator

      The accumulator function defines the value for the accumulator for the
      first reduction (or if iteration halts without any reduction).

      It can be initialised from an argument to the iterate step if needed.

      ## Reducer

      The reducer function takes the result of a previous map operation and
      uses it to generate a new accumulator value.

      ## Finaliser

      When the iterator halts iteration, the finaliser is called with allows
      you to perform a final operation on the accumulator before it is
      returned.

      > #### Warning {: .tip}
      >
      > You should not assume that these functions will all be called within
      > the same process, as they may be run asynchronously depending on the
      > configuration of the Reactor.
      """,
      examples: [
        """
        reduce do
          accumulator fn -> {:ok, %{}} end

          reducer fn word, counts ->
            {:cont, Map.update(counts, word, 1, &(&1 + 1))}
          end
        end
        """
      ],
      target: __MODULE__,
      identifier: {:auto, :unique_integer},
      schema: [
        accumulator: [
          type: {:or, [{:mfa_or_fun, 2}, {:mfa_or_fun, 1}, {:mfa_or_fun, 0}]},
          required: true,
          doc: "The initial accumulator value."
        ],
        finaliser: [
          type: {:or, [nil, {:mfa_or_fun, 2}, {:mfa_or_fun, 1}]},
          required: false,
          doc: "An optional final transformation function."
        ],
        reducer: [
          type: {:or, [{:mfa_or_fun, 3}, {:mfa_or_fun, 2}]},
          required: true,
          doc: "A function which reduces values into an accumulator."
        ]
      ]
    }

  @doc "The default accumulator."
  @spec default_accumulator :: {:ok, acc}
  def default_accumulator, do: {:ok, []}

  @doc "The default reducer."
  @spec default_reducer(element(), acc()) :: {:cont, acc}
  def default_reducer(element, acc), do: {:cont, [element | acc]}

  @doc "The default finaliser."
  @spec default_finaliser(acc) :: {:ok, acc}
  def default_finaliser(acc), do: {:ok, Enum.reverse(acc)}
end
