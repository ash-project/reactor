defmodule Reactor.Dsl.Debug do
  @moduledoc """
  The `debug` DSL entity struct.

  See `d:Reactor.debug`.
  """

  defstruct __identifier__: nil,
            arguments: [],
            guards: [],
            level: :debug,
            name: nil

  alias Reactor.Dsl.{Argument, Build, Debug, Guard, WaitFor, Where}

  @type t :: %Debug{
          __identifier__: any,
          arguments: [Argument.t()],
          guards: [Where.t() | Guard.t()],
          level: Logger.level(),
          name: atom
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :debug,
      describe: """
      Inserts a step which will send debug information to the `Logger`.
      """,
      examples: [
        """
        debug :debug do
          argument :suss, result(:suss_step)
        end
        """
      ],
      target: Debug,
      args: [:name],
      identifier: :name,
      entities: [
        arguments: [Argument.__entity__(), WaitFor.__entity__()],
        guards: [Where.__entity__(), Guard.__entity__()]
      ],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique identifier for the step.
          """
        ],
        level: [
          type: {:in, [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]},
          required: false,
          default: :debug,
          doc: """
          The log level to send the debug information to.
          """
        ]
      ]
    }

  defimpl Build do
    alias Reactor.{Builder, Step}

    def build(debug, reactor) do
      Builder.add_step(
        reactor,
        debug.name,
        {Step.Debug, level: debug.level},
        debug.arguments,
        guards: debug.guards,
        max_retries: 0,
        ref: :step_name
      )
    end

    def verify(_, _), do: :ok
    def transform(_, dsl_state), do: {:ok, dsl_state}
  end
end
