# Working with the Reactor Codebase

## Project Overview

Reactor is a framework-independent, dynamic, concurrent, dependency-resolving saga orchestrator for Elixir. While part of the ash-project organization with excellent Ash integration via Ash.Reactor, Reactor is designed to work with any Elixir application and orchestrate workflows across diverse systems and frameworks.

## Development Guidelines

### Understanding the Codebase

**Core Modules:**
- `Reactor` - Main module and DSL entry point
- `Reactor.Executor` - Handles reactor execution and concurrency
- `Reactor.Planner` - Builds dependency graphs and execution plans
- `Reactor.Step` - Behavior for implementing custom steps
- `Reactor.Builder` - Programmatic reactor construction
- `Reactor.Dsl.*` - DSL implementation modules

**Key Concepts:**
- **Steps** are units of work that can run synchronously or asynchronously
- **Arguments** define dependencies between steps
- **Compensation** handles step failures and retries
- **Undo** provides rollback capabilities for successful steps

### Code Organization

**lib/reactor/:**
- Core implementation in main directory
- `dsl/` - Spark DSL definitions and transformers
- `step/` - Built-in step implementations (map, compose, switch, etc.)
- `executor/` - Execution engine components
- `error/` - Error types and handling

**test/:**
- Unit tests mirror the lib/ structure
- `test/support/example/` - Example reactors for testing
- Integration tests in `test/reactor_test.exs`

### Development Workflow

**Before Making Changes:**
1. Read `usage-rules.md` to understand Reactor's API and patterns
2. Check existing tests to understand expected behavior
3. Look at examples in `test/support/example/` for patterns

**Testing:**
- Run full test suite: `mix test`
- Run specific test file: `mix test test/path/to/test.exs`
- Check formatting: `mix format --check-formatted`
- Type checking: `mix dialyzer` (if configured)

**Documentation:**
- Update relevant docstrings for public functions
- Add examples to moduledocs where helpful
- Update `usage-rules.md` if adding new DSL features
- Generate docs: `mix docs`

### Key Implementation Details

**DSL Architecture:**
- Uses Spark for DSL implementation
- DSL entities defined in `lib/reactor/dsl/`
- Transformers in `lib/reactor/dsl/` convert DSL to runtime structures

**Execution Model:**
- Reactor builds a dependency graph (DAG) from step arguments
- Executor runs steps concurrently when dependencies are satisfied
- State management handles intermediate results and step completion

**Error Handling:**
- Steps can implement `compensate/4` for error handling
- Steps can implement `undo/4` for rollback on later failures
- Retry logic controlled by compensation return values

### Ecosystem Extensions

**Framework Independence:**
- Reactor core has no hard dependencies on specific frameworks
- Extensions provide specialized capabilities via DSL entities
- Use `use Reactor, extensions: [Reactor.Req, Reactor.File, ...]` to include ecosystem packages

**Ecosystem Packages:**
- `reactor_file` - File system operations (copying, moving, permissions, I/O)
- `reactor_process` - Supervisor and process management operations
- `reactor_req` - HTTP client steps with DSL for all HTTP methods
- `Ash.Reactor` - Deep Ash framework integration (create, read, update, destroy, action steps)

**Bidirectional Ash Integration:**
- Reactor can orchestrate Ash actions from outside
- Reactor modules can serve as `run` implementation for Ash generic actions
- Action arguments validated against reactor inputs automatically

### Common Patterns

**Adding New Step Types:**
1. Create step module in `lib/reactor/step/`
2. Implement `Reactor.Step` behavior
3. Add DSL entity in `lib/reactor/dsl/`
4. Add tests in `test/reactor/step/`
5. Update documentation

**Adding DSL Features:**
1. Define entity in `lib/reactor/dsl/`
2. Add transformer if needed
3. Update `lib/reactor/dsl.ex` to include new entity
4. Add comprehensive tests
5. Update `usage-rules.md` with examples

**Error Types:**
- Use specific error modules in `lib/reactor/error/`
- Follow existing error hierarchy and patterns
- Include helpful context in error messages

### Testing Guidelines

**Step Testing:**
- Test step modules directly, not through reactors when possible
- Test all return value types: `{:ok, value}`, `{:error, reason}`, `:retry`, etc.
- Test compensation and undo logic separately

**Reactor Testing:**
- Use `async? false` for deterministic test execution
- Test with various input combinations
- Test error scenarios and recovery paths
- Test concurrent execution with appropriate timeouts

**Integration Testing:**
- Test complex reactor compositions
- Test with middleware
- Test halt/resume functionality

### Performance Considerations

**Concurrency:**
- Reactor runs steps asynchronously by default
- Use `async? false` only when necessary for ordering
- Consider memory usage with large numbers of concurrent steps
- Shared concurrency pools prevent resource exhaustion

**Large Workflows:**
- Be mindful of graph construction time for very large reactors
- Consider breaking large workflows into composed sub-reactors
- Monitor memory usage for long-running reactors

### Contributing Guidelines

**Code Style:**
- Follow Elixir community conventions
- Use descriptive names for steps, arguments, and variables
- Keep functions small and focused
- Add typespecs for public functions

**Documentation:**
- Write clear, concise docstrings
- Include examples for complex functions
- Update relevant documentation files
- Test examples in docstrings with doctests where appropriate

**Backwards Compatibility:**
- Avoid breaking changes to public APIs
- Deprecate features before removal
- Document migration paths for breaking changes

### Useful Commands

```bash
# Run all checks
mix check

# Run tests
mix test

# Format code
mix format

# Generate documentation
mix docs

# Run specific test file
mix test test/reactor/executor_test.exs

# Interactive development
iex -S mix
```

### Debugging Tips

**Reactor Execution:**
- Use `debug` steps to log intermediate values
- Set `async? false` to simplify execution flow
- Add telemetry middleware for observability

**Step Development:**
- Test steps in isolation first
- Use `dbg` for debugging
- Check argument structure and types

**DSL Issues:**
- Examine the generated struct with `Reactor.Info.to_struct/1`
- Check DSL transformer output
- Validate entity definitions

### Key Technical Patterns

**Recursive Execution:** Use `result(:step, :key)` NOT `result(:step, [:key])` for nested results
**Map Steps:** Use `source input(:name)` and `element(:map_step_name)` for proper references
**Step Return Values:** Use `{:ok, result, [new_steps]}` to emit new steps during execution
**Middleware Syntax:** Middleware goes inside `middlewares do ... end` blocks
**Extension Usage:** Use `use Reactor, extensions: [...]` to include ecosystem packages
**Concurrency Guidelines:** Modern multicore systems benefit from parallel CPU work - tune concurrency to workload, don't force sync
**Framework Independence:** Reactor works with any Elixir application, not just Ash

### Documentation Best Practices

**Visual Documentation with Mermaid:**
- ExDoc supports Mermaid diagrams with CDN integration
- Use `before_closing_head_tag` in mix.exs to include Mermaid JS
- Default theme works best for light/dark mode compatibility
- Include workflow diagrams in tutorials for better understanding
- Sequence diagrams excellent for showing error handling flows

**Comprehensive Documentation Structure:**
- Use DIATAXIS framework (Tutorials, How-to, Reference, Explanation)
- Structure mix.exs `extras` with proper sidebar groupings
- Fix relative links to use project root paths for ExDoc compatibility
- Include visual assets to enhance conceptual understanding
- Test documentation examples to prevent drift

**Testing Documentation:**
- Create validation tests for code examples in documentation
- Use simple, reliable approaches over complex innovative solutions
- Test both success and failure scenarios shown in docs
- Ensure examples work with current versions and dependencies

### Resources

- **Usage Guide:** `usage-rules.md` - Comprehensive API and patterns
- **Examples:** `test/support/example/` - Working reactor examples  
- **API Docs:** Generated with `mix docs`
- **Tests:** Extensive test suite shows expected behavior (use as tutorial example source)
- **Documentation:** `documentation/` - Complete Diataxis-structured learning materials
- **Community:** [Ash Discord](https://discord.gg/3hA2j4Jt) for ecosystem support and questions