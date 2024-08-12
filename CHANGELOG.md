# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.9.1](https://github.com/ash-project/reactor/compare/v0.9.0...v0.9.1) (2024-08-12)




### Bug Fixes:

* `Reactor.run!/4` should not return an `:ok` tuple.

## [v0.9.0](https://github.com/ash-project/reactor/compare/v0.8.5...v0.9.0) (2024-07-18)




### Features:

* map: Add the ability to map over elements of a collection inside a reactor. (#123)

* map: Add the ability to map over elements of a collection inside a reactor.

### Bug Fixes:

* automatically pass extra arguments from the map step to nested steps.

* spurious test failures seemingly caused by `Mimic`.

### Improvements:

* throw a more helpful error when a step returns an invalid result.

## [v0.8.5](https://github.com/ash-project/reactor/compare/v0.8.4...v0.8.5) (2024-07-10)




### Improvements:

* add `mix reactor.install` (#124)

## [v0.8.4](https://github.com/ash-project/reactor/compare/v0.8.3...v0.8.4) (2024-05-25)




### Bug Fixes:

* inability to store composed reactors at compile time.

## [v0.8.3](https://github.com/ash-project/reactor/compare/v0.8.2...v0.8.3) (2024-05-24)




### Bug Fixes:

* Missing `__identifier__` field in `compose` DSL struct.

## [v0.8.2](https://github.com/ash-project/reactor/compare/v0.8.1...v0.8.2) (2024-05-08)




### Bug Fixes:

* initialisation issue with middlewares.

## [v0.8.1](https://github.com/ash-project/reactor/compare/v0.8.0...v0.8.1) (2024-03-20)




### Bug Fixes:

* RunStepError: pass entire step struct instead of just name when raising.

## [v0.8.0](https://github.com/ash-project/reactor/compare/v0.7.0...v0.8.0) (2024-03-18)
### Breaking Changes:

* Use `Splode` for managing errors. (#97)



### Bug Fixes:

* Don't assume `UndefinedFunctionError` means the module is not a Reactor.

### Improvements:

* Add template guards.

## [v0.7.0](https://github.com/ash-project/reactor/compare/v0.6.0...v0.7.0) (2024-02-28)




### Features:

* Add telemetry middleware. (#93)

* Add a middleware which emits telemetry events about Reactor.

### Bug Fixes:

* incorrect function arity for `Group.after_fun` DSL.

### Improvements:

* don't incur compile-time dependencies on middleware.

## [v0.6.0](https://github.com/ash-project/reactor/compare/v0.5.2...v0.6.0) (2024-02-26)
### Breaking Changes:

* Remove hooks and replace with middleware behaviour. (#90)

* Remove hooks and replace with middleware behaviour.



### Improvements:

* Middleware: Add `get_process_context/0` and `set_process_context/1` middleware hooks.

* Add step event callback to middleware.

## [v0.5.2](https://github.com/ash-project/reactor/compare/v0.5.1...v0.5.2) (2024-02-18)




### Bug Fixes:

* callback spec for `Reactor.Step.async?/1`.

### Performance Improvements:

* Don't iterate the entire graph every time through the loop. (#88)

## [v0.5.1](https://github.com/ash-project/reactor/compare/v0.5.0...v0.5.1) (2024-02-14)




### Improvements:

* Move `can?/2` and `async?/1` into `Reactor.Step` behaviour. (#87)

## [v0.5.0](https://github.com/ash-project/reactor/compare/v0.4.1...v0.5.0) (2024-02-07)




### Features:

* Add lifecycle hooks to Reactor (#83)

### Bug Fixes:

* don't deadlock when lots of async reactors are sharing a concurrency pool. (#36)

* weird issue with aliases sometimes not being expanded in generated reactors. (#58)

### Improvements:

* Add ability for steps to decide at runtime whether they should be run asyncronously. (#84)

## [v0.4.1](https://github.com/ash-project/reactor/compare/v0.4.0...v0.4.1) (2023-09-26)




### Bug Fixes:

* weird issue with aliases sometimes not being expanded in generated reactors.

## [v0.4.0](https://github.com/ash-project/reactor/compare/v0.3.5...v0.4.0) (2023-09-11)




### Features:

* Add `collect` step entity. (#53)

## [v0.3.5](https://github.com/ash-project/reactor/compare/v0.3.4...v0.3.5) (2023-09-06)




### Improvements:

* Template: Abstract template type so that it can be used by extensions.

## [v0.3.4](https://github.com/ash-project/reactor/compare/v0.3.3...v0.3.4) (2023-09-04)




### Bug Fixes:

* Allow `reactor` DSL section to be patched.

* Reactor: fix call to `use Spark.Dsl`.

## [v0.3.3](https://github.com/ash-project/reactor/compare/v0.3.2...v0.3.3) (2023-09-01)




### Improvements:

* Dsl: Extract DSL entities into their target modules. (#50)

## [v0.3.2](https://github.com/ash-project/reactor/compare/v0.3.1...v0.3.2) (2023-07-27)




### Bug Fixes:

* Don't swallow errors when a step runs out of retries. (#41)

## [v0.3.1](https://github.com/ash-project/reactor/compare/v0.3.0...v0.3.1) (2023-07-24)




### Improvements:

* Add `wait_for` DSL. (#39)

* Add "subpaths" to templates. (#31)

* Step.Debug: Add `debug` step and DSL. (#30)

* Step.Switch: Add `switch` DSL and step type. (#29)

## [v0.3.0](https://github.com/ash-project/reactor/compare/v0.2.4...v0.3.0) (2023-07-03)




### Features:

* Step.Around: Add ability to wrap a function around a group of steps. (#24)

### Bug Fixes:

* Executor: don't double-iterate the graph each time through the loop.

### Improvements:

* Add `group` DSL entity and `Reactor.Step.Group`. (#27)

* Reactor.Executor: track concurrent process usage across multiple reactors. (#26)

* Support `timeout` and `async?` Reactor options. (#20)

* Invert DSL entity building. (#19)

* Allow entire step behaviour to be defined in the DSL. (#18)

### Performance Improvements:

* Dsl: Build and pre-plan DSL reactors.

* Builder: build transformation steps as synchronous.

## [v0.2.4](https://github.com/ash-project/reactor/compare/v0.2.3...v0.2.4) (2023-06-15)




### Improvements:

* Add ability to compose reactors.

* Builder: rename internally generated steps to start with `:__reactor__`. (#10)

## [v0.2.3](https://github.com/ash-project/reactor/compare/v0.2.2...v0.2.3) (2023-06-07)




### Improvements:

* Add step-wide argument transforms. (#9)

* Add step-wide argument transforms.

## [v0.2.2](https://github.com/ash-project/reactor/compare/v0.2.1...v0.2.2) (2023-05-15)




### Bug Fixes:

* Reactor.Argument: Remove spurious `is_atom` constraint on `Argument.from_input/2..3`.

## [v0.2.1](https://github.com/ash-project/reactor/compare/v0.2.0...v0.2.1) (2023-05-12)




### Improvements:

* Reactor.Step: remove `can?/1` and replace with optional callbacks. (#6)

## [v0.2.0](https://github.com/ash-project/reactor/compare/v0.1.0...v0.2.0) (2023-05-10)




### Features:

* implement basic reactor behaviour. (#1)

## [v0.1.0](https://github.com/ash-project/reactor/compare/v0.1.0...v0.1.0) (2023-04-19)



