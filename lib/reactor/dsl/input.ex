defmodule Reactor.Dsl.Input do
  @moduledoc """
  The struct used to store input DSL entities.

  See `d:Reactor.input`.
  """

  defstruct __identifier__: nil,
            description: nil,
            name: nil,
            transform: nil

  alias Reactor.{Builder, Dsl, Step}

  @type t :: %Dsl.Input{
          name: any,
          description: nil | String.t(),
          transform: {module, keyword},
          __identifier__: any
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :input,
      describe: """
      Specifies an input to the Reactor.

      An input is a value passed in to the Reactor when executing.
      If a Reactor were a function, these would be it's arguments.

      Inputs can be transformed with an arbitrary function before being passed
      to any steps.
      """,
      examples: [
        """
        input :name
        """,
        """
        input :age do
          transform &String.to_integer/1
        end
        """
      ],
      args: [:name],
      target: Dsl.Input,
      identifier: :name,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for this input. Used to allow steps to depend on it.
          """
        ],
        transform: [
          type: {:or, [{:spark_function_behaviour, Step, {Step.Transform, 1}}, nil]},
          required: false,
          default: nil,
          doc: """
          An optional transformation function which can be used to modify the input before it is passed to any steps.
          """
        ],
        description: [
          type: :string,
          required: false,
          doc: """
          An optional description for the input.
          """
        ]
      ]
    }

  defimpl Dsl.Build do
    def build(input, reactor) do
      Builder.add_input(reactor, input.name, input.transform)
    end

    def transform(_input, dsl_state), do: {:ok, dsl_state}
    def verify(_input, _dsl_state), do: :ok
  end
end
