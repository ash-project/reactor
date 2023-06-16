# Used by "mix format"
spark_locals_without_parens = [
  argument: 1,
  argument: 2,
  argument: 3,
  async?: 1,
  compensate: 1,
  compose: 2,
  compose: 3,
  input: 1,
  input: 2,
  max_retries: 1,
  return: 1,
  run: 1,
  step: 1,
  step: 2,
  step: 3,
  transform: 1,
  undo: 1
]

[
  import_deps: [:spark],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
