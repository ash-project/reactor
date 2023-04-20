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
      name: [type: :atom, required: true],
      transform: @transform
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
        required: true
      ],
      source: [
        type: {:or, [{:struct, Template.Input}, {:struct, Template.Result}]},
        required: true
      ],
      transform: @transform
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
        required: true
      ],
      impl: [
        type: {:spark_function_behaviour, Step, {Step.AnonFn, 3}},
        required: true
      ],
      max_retries: [
        type: {:or, [{:in, [:infinity]}, :non_neg_integer]},
        required: false,
        default: :infinity
      ],
      async?: [
        type: :boolean,
        required: false,
        default: true
      ]
    ]
  }

  @reactor %Section{
    name: :reactor,
    describe: "The top-level reactor DSL",
    schema: [
      return: [
        type: :atom,
        required: false
      ]
    ],
    entities: [@input, @step],
    top_level?: true
  }

  use Extension,
    sections: [@reactor],
    transformers: [Dsl.Transformer]
end
