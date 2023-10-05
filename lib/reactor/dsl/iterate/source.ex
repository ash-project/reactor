defmodule Reactor.Dsl.Iterate.Source do
  @moduledoc """
  The `iterate.source` DSL entity struct.

  See `d:Reactor.iterate.source`.
  """

  defstruct __identifier__: nil,
            finaliser: nil,
            generator: nil,
            initialiser: nil

  alias Reactor.{Builder, Dsl.Step}

  @type state :: any
  @type element :: Reactor.inputs()
  @type finaliser ::
          (state, Reactor.context() -> :ok | {:error, any}) | (state -> :ok | {:error, any})

  @type generator ::
          (state, Reactor.context() -> {:cont, [element], state} | {:halt, state} | {:error, any})
          | (state -> {:cont, [element], state} | {:halt, state} | {:error, any})

  @type initialiser ::
          (Reactor.inputs(), Reactor.context() -> {:ok, state} | {:error, any})
          | (Reactor.inputs() -> {:ok, state} | {:error, any})

  @type t :: %__MODULE__{
          __identifier__: any,
          finaliser: finaliser(),
          generator: generator(),
          initialiser: initialiser()
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :source,
      describe: """
      Provides the source of an iteration by lazily generating elements.

      Similar in semantics to `Stream.resource/3`, the `source` entity is
      responsible for generating values for use in iteration.

      ## Initialiser

      The initialiser is responsible for taking the arguments provided to the
      `iterate` step and returning a term which can be used as the input to the
      generator.

      You could use this to open a file for reading, or access an API endpoint.

      ## Generator

      The generator function takes the state from the initialiser and uses it
      to generate the next value(s) to map and reduce.

      Each element must be a map which can be accessed with the
      `element/1` helper.

      If your function returns more than one element the elements will be
      buffered inside the iterator.

      Your generator function will be called repeatedly until it returns a
      `:halt` tuple - even if it returns no elements.

      ## Finaliser

      When the generator halts iteration then the finaliser is called which
      allows you to clean up any resources in use if required.

      > #### Warning {: .tip}
      >
      > You should not assume that these functions will all be called within
      > the same process, as they may be run asynchronously depending on the
      > configuration of the Reactor.
      """,
      examples: [
        """
        source do
          initialiser fn args ->
            File.open(args.file, [:read])
          end

          generator fn file ->
            case IO.read(file, :line) do
              :eof -> {:halt, file}
              {:error, reason} -> {:error, reason}
              data -> {:cont, [%{line: data}], file}
            end
          end

          finaliser fn file ->
            File.close(file)
          end
        end
        """
      ],
      target: __MODULE__,
      identifier: {:auto, :unique_integer},
      schema: [
        finaliser: [
          type: {:or, [nil, {:mfa_or_fun, 2}, {:mfa_or_fun, 1}]},
          required: false,
          doc: "An optional clean up function."
        ],
        generator: [
          type: {:or, [{:mfa_or_fun, 2}, {:mfa_or_fun, 1}]},
          required: true,
          doc: "A function which emits the next value(s) for the iteration."
        ],
        initialiser: [
          type: {:or, [{:mfa_or_fun, 2}, {:mfa_or_fun, 1}]},
          required: true,
          doc: "A function which initialises the generator state."
        ]
      ]
    }
end
