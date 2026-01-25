<!--
SPDX-FileCopyrightText: 2026 James Harton, Zach Daniel, Alembic Pty and contributors
SPDX-FileCopyrightText: 2026 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>

SPDX-License-Identifier: MIT
-->

# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Build and Development Commands

```bash
# Run all quality checks (preferred - includes formatter, credo, dialyzer, tests, etc.)
mix check --no-retry

# Run tests
mix test                          # All tests
mix test test/reactor/step_test.exs  # Single test file
mix test test/reactor/step_test.exs:14  # Single test at line

# Individual checks (use mix check instead when possible)
mix format                        # Format code
mix format --check-formatted      # Verify formatting
mix credo --strict                # Linting
mix dialyzer                      # Type checking

# Generate documentation
mix docs                          # Also runs spark.cheat_sheets and spark.replace_doc_links

# Spark DSL formatting
mix spark.formatter --extensions Reactor.Dsl
```

## Architecture Overview

Reactor is a dynamic, concurrent, dependency-resolving saga orchestrator. It executes workflows as directed acyclic graphs (DAGs) with automatic dependency resolution and concurrent step execution.

### Core Execution Flow

1. **Define** - Reactor defined via DSL (`use Reactor`) or programmatically (`Reactor.Builder`)
2. **Plan** - `Reactor.Planner` converts steps into a `libgraph` DAG based on argument dependencies
3. **Execute** - `Reactor.Executor` processes the DAG, running async-ready steps concurrently
4. **Compensate/Undo** - On failure, steps are compensated then previously successful steps are undone

### Key Modules

- `Reactor` (`lib/reactor.ex`) - Main API: `run/4`, `undo/3`
- `Reactor.Step` (`lib/reactor/step.ex`) - Step behaviour with callbacks: `run/3`, `compensate/4`, `undo/4`, `backoff/4`
- `Reactor.Dsl` (`lib/reactor/dsl.ex`) - Spark DSL definition
- `Reactor.Executor` (`lib/reactor/executor.ex`) - DAG execution engine
- `Reactor.Planner` (`lib/reactor/planner.ex`) - Converts steps to execution graph
- `Reactor.Builder` (`lib/reactor/builder/`) - Programmatic reactor construction

### Step Types (lib/reactor/step/)

Built-in steps for common patterns:
- `AnonFn` - Anonymous function steps (used by DSL `run fn ... end`)
- `Compose` - Embed sub-reactors
- `Map` - Process collections with nested steps
- `Switch` - Conditional branching
- `Group` - Shared before_all/after_all hooks
- `Around` - Wrap step execution (e.g., transactions)
- `Recurse` - Iterative/recursive patterns

### Argument System

Arguments define step dependencies and data flow:
- `input(:name)` - Reference reactor input
- `result(:step_name)` - Reference another step's result
- `value(static)` - Static value
- `element(:map_step)` - Current element in Map context

Dependencies are automatically resolved from argument sources to build the execution graph.

### DSL Transformation Pipeline

1. DSL entities defined in `lib/reactor/dsl/` sections
2. `Reactor.Dsl.Transformer` converts DSL to `Reactor.Step` structs
3. `Reactor.Dsl.Verifier` validates configuration (return exists, no cycles, etc.)

## Testing Patterns

Tests use `ExUnit` with `async: true` where possible. Test support modules are in `test/support/`:
- `Example.Step.*` - Sample step implementations for testing
- Step modules can be tested in isolation using `Builder.new_step!/4`

For deterministic testing of concurrent workflows, use `async?: false` on steps.

## Conventions

- Uses [conventional commits](https://www.conventionalcommits.org/) for changelog generation
- REUSE compliant licensing (SPDX headers in all files)
- Spark DSL formatter configured in `.formatter.exs`
- Documentation follows Diátaxis framework (tutorials, how-to, explanation, reference)
