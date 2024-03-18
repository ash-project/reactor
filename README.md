# Reactor

![Elixir CI](https://github.com/ash-project/reactor/actions/workflows/elixir.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/reactor.svg)](https://hex.pm/packages/reactor)

Reactor is a dynamic, concurrent, dependency resolving saga orchestrator.

Woah. That's a lot. Let's break it down:

- **Saga orchestrator** A [saga][saga pattern] is a way of providing
  transaction-like semantics across multiple distinct resources.
- **Dependency resolving** reactor allows you to describe the dependencies
  between your saga steps using _arguments_ which are converted into a
  [DAG][dag] and used to compute execution order.
- **Concurrent** unless otherwise specified reactor will run as many steps as
  possible concurrently whilst taking into account the results of the dependency
  resolution.
- **Dynamic** whilst you can define a reactor statically using our awesome DSL,
  you can also build workflows dynamically - and even add steps while the
  reactor is running.

[saga pattern](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)

## Sponsors

Thanks to [Alembic Pty Ltd](https://alembic.com.au/) for sponsoring a portion of
this project's development.

## Installation

The package can be installed by adding `reactor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:reactor, "~> 0.8.0"}
  ]
end
```

## Documentation

Documentation for the latest release will be [available on
hexdocs](https://hexdocs.pm/reactor) and for the [`main`
branch](https://ash-project.github.io/reactor).

## Contributing

- To contribute updates, fixes or new features please fork and open a
  pull-request against `main`.
- Please use [conventional
  commits](https://www.conventionalcommits.org/en/v1.0.0/) - this allows us to
  dynamically generate the changelog.
- Feel free to ask any questions on the `#reactor` channel on the [Ash
  Discord](https://discord.gg/D7FNG2q).

## Licence

`reactor` is licensed under the terms of the [MIT
license](https://opensource.org/licenses/MIT). See the [`LICENSE` file in this
repository](https://github.com/ash-project/reactor/blob/main/LICENSE)
for details.

[saga pattern]: https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga
[dag]: https://en.wikipedia.org/wiki/Directed_acyclic_graph
