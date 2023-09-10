defmodule Reactor.Dsl.Step do
  @moduledoc """
  The struct used to store step DSL entities.

  See `d:Reactor.step`.
  """

  defstruct __identifier__: nil,
            arguments: [],
            async?: true,
            compensate: nil,
            impl: nil,
            max_retries: :infinity,
            name: nil,
            run: nil,
            transform: nil,
            undo: nil

  alias Reactor.{Builder, Dsl, Step}

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
                 {:ok, any} | {:ok, any, [Step.t()]} | {:halt | :error, any}),
          transform: nil | (any -> any),
          undo: nil | (any, Reactor.inputs(), Reactor.context() -> :ok | :retry | {:error, any}),
          __identifier__: any
        }

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :step,
      describe: """
      Specifies a Reactor step.

      Steps are the unit of work in a Reactor.  Reactor will calculate the
      dependencies graph between the steps and execute as many as it can in each
      iteration.

      See the `Reactor.Step` behaviour for more information.
      """,
      examples: [
        """
        step :create_user, MyApp.Steps.CreateUser do
          argument :username, input(:username)
          argument :password_hash, result(:hash_password)
        end
        """,
        """
        step :hash_password do
          argument :password, input(:password)

          run fn %{password: password}, _ ->
            {:ok, Bcrypt.hash_pwd_salt(password)}
          end
        end
        """
      ],
      args: [:name, {:optional, :impl}],
      target: __MODULE__,
      identifier: :name,
      no_depend_modules: [:impl],
      entities: [arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()]],
      recursive_as: :steps,
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          A unique name for the step.

          This is used when choosing the return value of the Reactor and for arguments into
          other steps.
          """
        ],
        impl: [
          type: {:or, [{:spark_behaviour, Step}, nil]},
          required: false,
          doc: """
          The step implementation.

          Provides an implementation for the step with the named module.  The
          module must implement the `Reactor.Step` behaviour.
          """
        ],
        run: [
          type: {:or, [{:mfa_or_fun, 1}, {:mfa_or_fun, 2}]},
          required: false,
          doc: """
          Provide an anonymous function which implements the `run/3` callback.

          You cannot provide this option at the same time as the `impl` argument.
          """
        ],
        undo: [
          type: {:or, [{:mfa_or_fun, 1}, {:mfa_or_fun, 2}, {:mfa_or_fun, 3}]},
          required: false,
          doc: """
          Provide an anonymous function which implements the `undo/4` callback.

          You cannot provide this option at the same time as the `impl` argument.
          """
        ],
        compensate: [
          type: {:or, [{:mfa_or_fun, 1}, {:mfa_or_fun, 2}, {:mfa_or_fun, 3}]},
          required: false,
          doc: """
          Provide an anonymous function which implements the `undo/4` callback.

          You cannot provide this option at the same time as the `impl` argument.
          """
        ],
        max_retries: [
          type: {:or, [{:in, [:infinity]}, :non_neg_integer]},
          required: false,
          default: :infinity,
          doc: """
          The maximum number of times that the step can be retried before failing.

          This is only used when the result of the `compensate/4` callback is
          `:retry`.
          """
        ],
        async?: [
          type: :boolean,
          required: false,
          default: true,
          doc: """
          When set to true the step will be executed asynchronously via Reactor's
          `TaskSupervisor`.
          """
        ],
        transform: [
          type: {:or, [{:spark_function_behaviour, Step, {Step.TransformAll, 1}}, nil]},
          required: false,
          default: nil,
          doc: """
          An optional transformation function which can be used to modify the
          entire argument map before it is passed to the step.
          """
        ]
      ]
    }

  defimpl Dsl.Build do
    alias Spark.Error.DslError

    def build(step, reactor) do
      with {:ok, step} <- rewrite_step(step, reactor.id) do
        Builder.add_step(reactor, step.name, step.impl, step.arguments,
          async?: step.async?,
          max_retries: step.max_retries,
          transform: step.transform,
          ref: :step_name
        )
      end
    end

    def transform(_step, dsl_state), do: {:ok, dsl_state}

    def verify(_step, _dsl_state), do: :ok

    defp rewrite_step(step, module) when is_nil(step.impl) and is_nil(step.run),
      do:
        {:error,
         DslError.exception(
           module: module,
           path: [:reactor, :step, step.name],
           message: "Step has no implementation"
         )}

    defp rewrite_step(step, module) when not is_nil(step.impl) and not is_nil(step.run),
      do:
        {:error,
         DslError.exception(
           module: module,
           path: [:reactor, :step, step.name],
           message: "Step has both an implementation module and a run function"
         )}

    defp rewrite_step(step, module)
         when not is_nil(step.impl) and not is_nil(step.compensate),
         do:
           {:error,
            DslError.exception(
              module: module,
              path: [:reactor, :step, step.name],
              message: "Step has both an implementation module and a compensate function"
            )}

    defp rewrite_step(step, module) when not is_nil(step.impl) and not is_nil(step.undo),
      do:
        {:error,
         DslError.exception(
           module: module,
           path: [:reactor, :step, step.name],
           message: "Step has both an implementation module and a undo function"
         )}

    defp rewrite_step(step, _dsl_state)
         when is_nil(step.run) and is_nil(step.compensate) and is_nil(step.undo) and
                not is_nil(step.impl),
         do: {:ok, step}

    defp rewrite_step(step, _dsl_state),
      do:
        {:ok,
         %{
           step
           | impl:
               {Reactor.Step.AnonFn, run: step.run, compensate: step.compensate, undo: step.undo},
             run: nil,
             compensate: nil,
             undo: nil
         }}
  end
end
