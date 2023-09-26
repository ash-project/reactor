defmodule Reactor.Dsl.Switch do
  @moduledoc """
  The `switch` DSL entity struct.

  See `d:Reactor.switch`.
  """
  defstruct __identifier__: nil,
            allow_async?: true,
            default: nil,
            matches: [],
            name: nil,
            on: nil

  alias Reactor.{
    Dsl.Argument,
    Dsl.Build,
    Dsl.Switch,
    Dsl.Switch.Default,
    Dsl.Switch.Match,
    Step,
    Template
  }

  @type t :: %Switch{
          __identifier__: any,
          allow_async?: boolean,
          default: nil | Default.t(),
          matches: [Match.t()],
          name: atom,
          on: Template.Input.t() | Template.Result.t() | Template.Value.t()
        }

  @switch_match %Spark.Dsl.Entity{
    name: :matches?,
    describe: """
    A group of steps to run when the predicate matches.
    """,
    target: Match,
    args: [:predicate],
    entities: [steps: []],
    schema: [
      predicate: [
        type: {:mfa_or_fun, 1},
        required: true,
        doc: """
        A one-arity function which is used to match the switch input. If the switch returns a truthy value, then the nested steps will be run.
        """
      ],
      allow_async?: [
        type: :boolean,
        required: false,
        default: true,
        doc: """
        Whether the emitted steps should be allowed to run asynchronously.
        """
      ],
      return: [
        type: :atom,
        required: false,
        doc: """
        Specify which step result to return upon completion.
        """
      ]
    ]
  }

  @switch_default %Spark.Dsl.Entity{
    name: :default,
    describe: """
    If none of the `matches?` branches match the input, then the `default`
    steps will be run if provided.
    """,
    target: Default,
    entities: [steps: []],
    schema: [
      return: [
        type: :atom,
        required: false,
        doc: """
        Specify which step result to return upon completion.
        """
      ]
    ]
  }

  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :switch,
      describe: """
      Use a predicate to determine which steps should be executed.
      """,
      target: Switch,
      args: [:name],
      identifier: :name,
      imports: [Argument],
      entities: [matches: [@switch_match], default: [@switch_default]],
      singleton_entity_keys: [:default],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for the switch.
          """
        ],
        allow_async?: [
          type: :boolean,
          required: false,
          default: true,
          doc: """
          Whether the emitted steps should be allowed to run asynchronously.
          """
        ],
        on: [
          type: Template.type(),
          required: true,
          doc: """
          The value to match against.
          """
        ]
      ]
    }

  defimpl Build do
    import Reactor.Utils
    alias Reactor.{Argument, Builder, Planner}
    alias Spark.{Dsl.Verifier, Error.DslError}

    def build(switch, reactor) do
      with {:ok, matches} <- build_matches(switch, reactor),
           {:ok, default} <- build_default(switch, reactor) do
        Builder.add_step(
          reactor,
          switch.name,
          {Step.Switch,
           on: :value, matches: matches, default: default, allow_async?: switch.allow_async?},
          [%Argument{name: :value, source: switch.on}],
          async?: switch.allow_async?,
          max_retries: 0,
          ref: :step_name
        )
      end
    end

    def verify(switch, dsl_state) when switch.matches == [] do
      {:error,
       DslError.exception(
         module: Verifier.get_persisted(dsl_state, :module),
         path: [:reactor, :switch, :matches?, switch.name],
         message: "No match branches provided for switch"
       )}
    end

    def verify(_switch, _dsl_state), do: :ok

    def transform(_switch, dsl_state), do: {:ok, dsl_state}

    defp build_matches(switch, reactor) do
      map_while_ok(switch.matches, &build_match(&1, switch, reactor), true)
    end

    defp build_match(match, switch, reactor) do
      with {:ok, reactor} <- build_steps(match.steps, reactor),
           {:ok, reactor} <- maybe_build_return_step(match.return, switch, reactor),
           {:ok, _} <- Planner.plan(reactor) do
        {:ok, {match.predicate, reactor.steps}}
      end
    end

    defp build_default(switch, _reactor) when is_nil(switch.default), do: {:ok, []}

    defp build_default(switch, reactor) do
      with {:ok, reactor} <- build_steps(switch.default.steps, reactor),
           {:ok, reactor} <- maybe_build_return_step(switch.default.return, switch, reactor),
           {:ok, _} <- Planner.plan(reactor) do
        {:ok, reactor.steps}
      end
    end

    defp build_steps(steps, reactor), do: reduce_while_ok(steps, reactor, &Build.build/2)

    defp maybe_build_return_step(nil, _, reactor), do: {:ok, reactor}

    defp maybe_build_return_step(return_name, switch, reactor) do
      Builder.add_step(
        reactor,
        switch.name,
        {Step.ReturnArgument, argument: :value},
        [Argument.from_result(:value, return_name)],
        async?: switch.allow_async?,
        max_retries: 0,
        ref: :step_name
      )
    end
  end
end
