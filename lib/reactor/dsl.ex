defmodule Reactor.Dsl do
  @moduledoc false

  alias Reactor.{Argument, Dsl, Input, Step, Template}
  alias Spark.Dsl.{Entity, Extension, Section}

  @transform [
    type: {:or, [{:spark_function_behaviour, Step, {Step.Transform, 1}}, nil]},
    required: false,
    default: nil
  ]

  @input %Entity{
    name: :input,
    args: [:name],
    target: Input,
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
    args: [:name, {:optional, :source}],
    target: Argument,
    imports: [Argument.Templates],
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
        type: {:or, [{:struct, Template.Input}, {:struct, Template.Result}]},
        required: true,
        doc: """
        What to use as the source of the argument.

        See `Reactor.Argument.Templates` for more information.
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
    args: [:name, {:optional, :impl}],
    target: Step,
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
        type: {:spark_function_behaviour, Step, {Step.AnonFn, 3}},
        required: true,
        doc: """
        The step implementation.

        The implementation can be either a module which implements the
        `Reactor.Step` behaviour or an anonymous function or function capture
        with an arity of 2.

        Note that steps which are implemented as functions cannot be
        compensated or undone.
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

          Note that due to the fact that step arguments must be a map, and this
          function can return any value it's result will be placed in the
          `:input` key in the step's argument map.
          """
        )
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
    entities: [@input, @step],
    top_level?: true
  }

  use Extension,
    sections: [@reactor],
    transformers: [Dsl.Transformer]
end
