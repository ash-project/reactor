defmodule Reactor.Dsl.Collect do
  @moduledoc """
  The struct used to store collect DSL entities.

  See `d:Reactor.collect`.
  """

  defstruct __identifier__: nil,
            arguments: [],
            name: nil,
            transform: nil

  alias Reactor.{Builder, Dsl, Step}

  @type t :: %__MODULE__{
          arguments: [Dsl.Argument.t()],
          name: atom,
          transform: nil | (any -> any),
          __identifier__: any
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :collect,
      describe: """
      A Reactor step which simply collects and returns it's arguments.

      Arguments can optionally be transformed before returning.
      """,
      examples: [
        """
        collect :latest_release_uri do
          argument :repository, input(:repository)
          argument :organisation, input(:organisation)

          transform fn inputs ->
            %{uri: "https://api.github.com/repos/\#{inputs.organisation}/\#{inputs.repository}/releases/latest"}
          end
        end
        """
      ],
      args: [:name],
      target: __MODULE__,
      identifier: :name,
      entities: [arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()]],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for the step. Used when choosing the return value of the Reactor and for arguments into other steps.
          """
        ],
        transform: [
          type: {:or, [{:spark_function_behaviour, Step, {Step.TransformAll, 1}}, nil]},
          required: false,
          default: nil,
          doc: """
          An optional transformation function which can be used to modify the entire argument map before it is returned.
          """
        ]
      ]
    }

  defimpl Dsl.Build do
    def build(collect, reactor) do
      Builder.add_step(
        reactor,
        collect.name,
        Step.ReturnAllArguments,
        collect.arguments,
        async?: true,
        max_retries: 1,
        transform: collect.transform,
        ref: :step_name
      )
    end

    def verify(_collect, _dsl_state), do: :ok
    def transform(_collect, dsl_state), do: {:ok, dsl_state}
  end
end
