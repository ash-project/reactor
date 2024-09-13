defmodule Reactor.Dsl.Flunk do
  @moduledoc """
  The struct used to store flunk DSL entities.

  See `d:Reactor.flunk`.
  """

  alias Reactor.{Dsl.Argument, Dsl.Build, Dsl.Flunk, Dsl.WaitFor, Step, Template}

  defstruct __identifier__: nil,
            arguments: [],
            name: nil,
            message: nil

  @type t :: %Flunk{
          __identifier__: any,
          arguments: [Argument.t()],
          message: Template.t(),
          name: atom
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :flunk,
      describe: """
      Creates a step which will always cause the Reactor to exit with an error.

      This step will flunk with a `Reactor.Error.Invalid.ForcedFailureError` with it's message set to the provided message.
      Additionally, any arguments to the step will be stored in the exception under the `arguments` key.
      """,
      examples: [
        """
        flunk :outaroad, "Ran out of road before reaching 88Mph"
        """
      ],
      args: [:name, :message],
      target: __MODULE__,
      entities: [arguments: [Argument.__entity__(), WaitFor.__entity__()]],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for the step. Used when choosing the return value of the Reactor and for arguments into other steps.
          """
        ],
        message: [
          type: {:or, [nil, :string, Template.type()]},
          required: false,
          default: nil,
          doc: """
          The message to to attach to the exception.
          """
        ]
      ]
    }

  defimpl Build do
    require Reactor.Template
    alias Reactor.{Argument, Builder, Step}
    import Reactor.Utils

    def build(flunk, reactor) do
      with {:ok, reactor} <-
             Builder.add_step(
               reactor,
               {flunk.name, :arguments},
               Step.ReturnAllArguments,
               flunk.arguments,
               async?: true,
               max_retries: 1,
               ref: :step_name
             ) do
        arguments =
          [Argument.from_result(:arguments, {flunk.name, :arguments})]
          |> maybe_append(message_argument(flunk))

        Builder.add_step(reactor, flunk.name, Step.Fail, arguments,
          max_retries: 0,
          ref: :step_name
        )
      end
    end

    defp message_argument(flunk) when is_binary(flunk.message),
      do: Argument.from_value(:message, flunk.message)

    defp message_argument(flunk) when Template.is_template(flunk.message),
      do: Argument.from_template(:message, flunk.message)

    defp message_argument(flunk) when is_nil(flunk.message), do: nil

    def verify(_, _), do: :ok
    def transform(_, dsl_state), do: {:ok, dsl_state}
  end
end
