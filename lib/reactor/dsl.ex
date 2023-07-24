defmodule Reactor.Dsl do
  @moduledoc false

  alias Reactor.{Dsl, Step, Template}
  alias Spark.Dsl.{Entity, Extension, Section}

  @transform [
    type: {:or, [{:spark_function_behaviour, Step, {Step.Transform, 1}}, nil]},
    required: false,
    default: nil
  ]

  @input %Entity{
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
        A unique name for this input.

        The name is used to allow steps to depend on it.
        """
      ],
      transform:
        Keyword.put(@transform, :doc, """
        An optional transformation function which can be used to modify the
        input before it is passed to any steps.
        """)
    ]
  }

  @argument %Entity{
    name: :argument,
    describe: """
    Specifies an argument to a Reactor step.

    Each argument is a value which is either the result of another step, or an input value.

    Individual arguments can be transformed with an arbitrary function before
    being passed to any steps.
    """,
    examples: [
      """
      argument :name, input(:name)
      """,
      """
      argument :year, input(:date, [:year])
      """,
      """
      argument :user, result(:create_user)
      """,
      """
      argument :user_id, result(:create_user) do
        transform & &1.id
      end
      """,
      """
      argument :user_id, result(:create_user, [:id])
      """,
      """
      argument :three, value(3)
      """
    ],
    args: [:name, {:optional, :source}],
    target: Dsl.Argument,
    identifier: :name,
    imports: [Dsl.Argument],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: """
        The name of the argument which will be used as the key in the
        `arguments` map passed to the implementation.
        """
      ],
      source: [
        type:
          {:or,
           [{:struct, Template.Input}, {:struct, Template.Result}, {:struct, Template.Value}]},
        required: true,
        doc: """
        What to use as the source of the argument.

        See `Reactor.Dsl.Argument` for more information.
        """
      ],
      transform:
        Keyword.put(@transform, :doc, """
        An optional transformation function which can be used to modify the
        argument before it is passed to the step.
        """)
    ]
  }

  @wait_for %Entity{
    name: :wait_for,
    describe: """
    Wait for the named step to complete before allowing this one to start.

    Desugars to `argument :_, result(step_to_wait_for)`
    """,
    examples: ["wait_for :create_user"],
    args: [:names],
    target: Dsl.WaitFor,
    schema: [
      names: [
        type: {:wrap_list, :atom},
        required: true,
        doc: """
        The name of the step to wait for.
        """
      ]
    ]
  }

  @step %Entity{
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
    target: Dsl.Step,
    identifier: :name,
    no_depend_modules: [:impl],
    entities: [arguments: [@argument, @wait_for]],
    recursive_as: :steps,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: """
        A unique name for the step.

        This is used when choosing the return value of the Reactor and for arguments into
        another step.
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
      transform:
        Keyword.merge(@transform,
          type: {:or, [{:spark_function_behaviour, Step, {Step.TransformAll, 1}}, nil]},
          doc: """
          An optional transformation function which can be used to modify the
          entire argument map before it is passed to the step.
          """
        )
    ]
  }

  @compose %Entity{
    name: :compose,
    describe: """
    Compose another Reactor into this one.

    Allows place another Reactor into this one as if it were a single step.
    """,
    args: [:name, :reactor],
    target: Dsl.Compose,
    identifier: :name,
    no_depend_modules: [:reactor],
    entities: [arguments: [@argument, @wait_for]],
    recursive_as: :steps,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: """
        A unique name for the step.

        Allows the result of the composed reactor to be depended upon by steps
        in this reactor.
        """
      ],
      reactor: [
        type: {:or, [{:struct, Reactor}, {:spark, Reactor.Dsl}]},
        required: true,
        doc: """
        The reactor module or struct to compose upon.
        """
      ]
    ]
  }

  @around %Entity{
    name: :around,
    describe: """
    Wrap a function around a group of steps.
    """,
    target: Dsl.Around,
    args: [:name, {:optional, :fun}],
    identifier: :name,
    entities: [steps: [], arguments: [@argument, @wait_for]],
    recursive_as: :steps,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: """
        A unique name of the group of steps.
        """
      ],
      fun: [
        type: {:mfa_or_fun, 4},
        required: true,
        doc: """
        The around function.

        See `Reactor.Step.Around` for more information.
        """
      ],
      allow_async?: [
        type: :boolean,
        required: false,
        default: false,
        doc: """
        Whether the emitted steps should be allowed to run asynchronously.

        Passed to the child Reactor as it's `async?` option.
        """
      ]
    ]
  }

  @group %Entity{
    name: :group,
    describe: """
    Call functions before and after a group of steps.
    """,
    target: Dsl.Group,
    args: [:name],
    identifier: :name,
    entities: [steps: [], arguments: [@argument, @wait_for]],
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

  @switch_match %Entity{
    name: :matches?,
    describe: """
    A group of steps to run when the predicate matches.
    """,
    target: Dsl.Switch.Match,
    args: [:predicate],
    entities: [steps: []],
    schema: [
      predicate: [
        type: {:mfa_or_fun, 1},
        required: true,
        doc: """
        A one-arity function which is used to match the switch input.

        If the switch returns a truthy value, then the nested steps will be run.
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

  @switch_default %Entity{
    name: :default,
    describe: """
    If none of the `matches?` branches match the input, then the `default`
    steps will be run if provided.
    """,
    target: Dsl.Switch.Default,
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

  @switch %Entity{
    name: :switch,
    describe: """
    Use a predicate to determine which steps should be executed.
    """,
    target: Dsl.Switch,
    args: [:name],
    identifier: :name,
    imports: [Dsl.Argument],
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
        type:
          {:or,
           [{:struct, Template.Input}, {:struct, Template.Result}, {:struct, Template.Value}]},
        required: true,
        doc: """
        The value to match against.
        """
      ]
    ]
  }

  @debug %Entity{
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
    target: Dsl.Debug,
    args: [:name],
    identifier: :name,
    entities: [arguments: [@argument, @wait_for]],
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

  @reactor %Section{
    name: :reactor,
    describe: "The top-level reactor DSL",
    schema: [
      return: [
        type: :atom,
        required: false,
        doc: """
        Specify which step result to return upon completion.
        """
      ]
    ],
    entities: [@around, @debug, @group, @input, @step, @switch, @compose],
    top_level?: true
  }

  use Extension,
    sections: [@reactor],
    transformers: [Dsl.Transformer],
    verifiers: [Dsl.Verifier]
end
