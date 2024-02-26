# Used by "mix format"
spark_locals_without_parens = [
  after_all: 1,
  allow_async?: 1,
  argument: 1,
  argument: 2,
  argument: 3,
  around: 1,
  around: 2,
  around: 3,
  async?: 1,
  before_all: 1,
  collect: 1,
  collect: 2,
  compensate: 1,
  compose: 2,
  compose: 3,
  debug: 1,
  debug: 2,
  default: 0,
  default: 1,
  group: 1,
  group: 2,
  input: 1,
  input: 2,
  level: 1,
  matches?: 1,
  matches?: 2,
  max_retries: 1,
  middleware: 1,
  middleware: 2,
  on: 1,
  return: 1,
  run: 1,
  step: 1,
  step: 2,
  step: 3,
  switch: 1,
  switch: 2,
  transform: 1,
  undo: 1,
  wait_for: 1,
  wait_for: 2
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
