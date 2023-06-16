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
      argument :user, result(:create_user)
      """,
      """
      argument :user_id, result(:create_user) do
        transform & &1.id
      end
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
    entities: [arguments: [@argument]],
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
        type: {:mfa_or_fun, 2},
        required: false,
        doc: """
        Provide an anonymous function which implements the `run/3` callback.

        You cannot provide this option at the same time as the `impl` argument.
        """
      ],
      undo: [
        type: {:mfa_or_fun, 3},
        required: false,
        doc: """
        Provide an anonymous function which implements the `undo/4` callback.

        You cannot provide this option at the same time as the `impl` argument.
        """
      ],
      compensate: [
        type: {:mfa_or_fun, 3},
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
    entities: [arguments: [@argument]],
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
    entities: [@input, @step, @compose],
    top_level?: true
  }

  use Extension,
    sections: [@reactor],
    transformers: [Dsl.Transformer],
    verifiers: [Dsl.PlanableVerifier]
end
