defmodule Reactor.Dsl.Group do
  @moduledoc """
  The `group` DSL entity struct.

  See `d:Reactor.group`.
  """
  defstruct __identifier__: nil,
            allow_async?: false,
            arguments: [],
            before_all: nil,
            after_all: nil,
            name: nil,
            steps: []

  alias Reactor.{Builder, Dsl, Step}

  @type t :: %Dsl.Group{
          __identifier__: any,
          allow_async?: true,
          arguments: [Dsl.Argument.t()],
          before_all: mfa | Step.Group.before_fun(),
          after_all: mfa | Step.Group.after_fun(),
          name: atom,
          steps: [Dsl.Step.t()]
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :group,
      describe: """
      Call functions before and after a group of steps.
      """,
      target: Dsl.Group,
      args: [:name],
      identifier: :name,
      entities: [steps: [], arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()]],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for the group of steps.
          """
        ],
        before_all: [
          type: {:mfa_or_fun, 3},
          required: true,
          doc: """
          The before function.

          See `Reactor.Step.Group` for more information.
          """
        ],
        after_all: [
          type: {:mfa_or_fun, 3},
          required: true,
          doc: """
          The after function.

          See `Reactor.Step.Group` for more information.
          """
        ],
        allow_async?: [
          type: :boolean,
          required: false,
          default: true,
          doc: """
          Whether the emitted steps should be allowed to run asynchronously.

          Passed to the child Reactor as it's `async?` option.
          """
        ]
      ]
    }

  defimpl Dsl.Build do
    import Reactor.Utils
    alias Spark.{Dsl.Verifier, Error.DslError}

    def build(group, reactor) do
      sub_reactor = Builder.new(reactor.id)

      with {:ok, sub_reactor} <- build_inputs(sub_reactor, group),
           {:ok, sub_reactor} <- build_steps(sub_reactor, group) do
        Builder.add_step(
          reactor,
          group.name,
          {Step.Group,
           before: group.before_all,
           after: group.after_all,
           steps: sub_reactor.steps,
           allow_async?: group.allow_async?},
          group.arguments,
          async?: group.allow_async?,
          max_retries: 0,
          ref: :step_name
        )
      end
    end

    def verify(group, dsl_state) when group.steps == [] do
      {:error,
       DslError.exception(
         module: Verifier.get_persisted(dsl_state, :module),
         path: [:reactor, :group, group.name],
         message: "Group contains no steps"
       )}
    end

    def verify(_group, _dsl_state), do: :ok

    def transform(_around, dsl_state), do: {:ok, dsl_state}

    defp build_inputs(reactor, around) do
      around.arguments
      |> Enum.map(& &1.name)
      |> reduce_while_ok(reactor, &Builder.add_input(&2, &1))
    end

    defp build_steps(reactor, group) do
      group.steps
      |> reduce_while_ok(reactor, &Dsl.Build.build/2)
    end
  end
end
