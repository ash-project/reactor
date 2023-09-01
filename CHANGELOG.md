# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

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



