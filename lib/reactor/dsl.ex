defmodule Reactor.Dsl do
  @moduledoc false

  alias Reactor.Dsl
  alias Spark.Dsl.{Extension, Section}

  @middleware %Section{
    name: :middlewares,
    describe: "Middleware to be added to the Reactor",
    entities: [Dsl.Middleware.__entity__()],
    patchable?: true
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
    entities: [
      Dsl.Around.__entity__(),
      Dsl.Collect.__entity__(),
      Dsl.Compose.__entity__(),
      Dsl.Debug.__entity__(),
      Dsl.Flunk.__entity__(),
      Dsl.Group.__entity__(),
      Dsl.Input.__entity__(),
      Dsl.Map.__entity__(),
      Dsl.Step.__entity__(),
      Dsl.Switch.__entity__()
    ],
    sections: [@middleware],
    top_level?: true,
    patchable?: true
  }

  use Extension,
    sections: [@reactor],
    transformers: [Dsl.Transformer],
    verifiers: [Dsl.Verifier]
end
