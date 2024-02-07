defmodule Reactor do
  alias Reactor.{Dsl, Executor, Step}

  @moduledoc """
  Reactor is a dynamic, concurrent, dependency resolving saga orchestrator.

  ## Usage

  You can construct a reactor using the `Reactor` Spark DSL:

  ```elixir
  defmodule HelloWorldReactor do
    @moduledoc false
    use Reactor

    input :whom

    step :greet, Greeter do
      argument :whom, input(:whom)
    end

    return :greet
  end
  ```

      iex> Reactor.run(HelloWorldReactor, %{whom: "Dear Reader"})
      {:ok, "Hello, Dear Reader!"}

  or you can build it programmatically:

      iex> reactor = Builder.new()
      ...> {:ok, reactor} = Builder.add_input(reactor, :whom)
      ...> {:ok, reactor} = Builder.add_step(reactor, :greet, Greeter, whom: {:input, :whom})
      ...> {:ok, reactor} = Builder.return(reactor, :greet)
      ...> Reactor.run(reactor, %{whom: nil})
      {:ok, "Hello, World!"}


  ## Hooks

  Reactor allows you to add lifecycle hooks using functions in
  `Reactor.Builder`.  Lifecycle hooks will be called in the order that they are
  added to the reactor.

  Four kinds of lifecycle hooks are provided:

  * `complete` - These hooks will be called with the result of the reactor run
    when the run is successful.  If you return `{:ok, new_result}` then the
    result is replaced with the new value.
  * `error` - These hooks will be called with an error (or list of errors) which
    were raised or returned during the reactor run.  You can either return `:ok`
    or a new error tuple to replace the error result.
  * `halt` - These hooks are called when the reactor is being halted and allows
    you to mutate the context before the halted reactor is returned.
  * `init` - These hooks are called when the reactor is first run or is resumed
    from a previous halted state and allow you to mutate the context before the
    reactor run is started.
  """

  defstruct context: %{},
            hooks: %{},
            id: nil,
            inputs: [],
            intermediate_results: %{},
            plan: nil,
            return: nil,
            state: :pending,
            steps: [],
            undo: []

  use Spark.Dsl, default_extensions: [extensions: [Dsl]]

  @type context :: %{optional(atom) => any}
  @type context_arg :: Enumerable.t({atom, any})

  @typedoc """
  Specify the maximum number of asynchronous steps which can be run in parallel.

  Defaults to the result of `System.schedulers_online/0`.  Only used if
  `async?` is set to `true`.
  """
  @type max_concurrency_option :: {:max_concurrency, pos_integer()}

  @typedoc """
  Specify the amount of execution time after which to halt processing.

  Note that this is not a hard limit. The Reactor will stop when the first step
  completes _after_ the timeout has expired.

  Defaults to `:infinity`.
  """
  @type timeout_option :: {:timeout, pos_integer() | :infinity}

  @typedoc """
  The maximum number of iterations which after which the Reactor will halt.

  Defaults to `:infinity`.
  """
  @type max_iterations_option :: {:max_iterations, pos_integer() | :infinity}

  @typedoc """
  How long to wait for asynchronous steps to complete when halting.

  Defaults to 5000ms.
  """
  @type halt_timeout_option :: {:halt_timeout, pos_integer() | :infinity}

  @typedoc """
  When set to `false` forces the Reactor to run every step synchronously,
  regardless of the step configuration.

  Defaults to `true`.
  """
  @type async_option :: {:async?, boolean}

  @typedoc """
  Use a `Reactor.Executor.ConcurrencyTracker.pool_key` to allow this Reactor to
  share it's concurrency pool with other Reactor instances.

  If you do not specify one then the Reactor will initialise a new pool and
  place it in it's context for any child Reactors to re-use.

  Only used if `async?` is set to `true`.
  """
  @type concurrency_key_option :: {:concurrency_key, reference()}

  @type options ::
          Enumerable.t(
            max_concurrency_option
            | timeout_option
            | max_iterations_option
            | halt_timeout_option
            | async_option
            | concurrency_key_option
          )

  @type state :: :pending | :executing | :halted | :failed | :successful
  @type inputs :: %{optional(atom) => any}

  @type complete_hook :: mfa | (result :: any, context -> {:ok, result :: any} | {:error, any})
  @type error_hook :: mfa | (error :: any, context -> :ok | {:error, any})
  @type halt_hook :: mfa | (context -> {:ok, context} | {:error, any})
  @type init_hook :: mfa | (context -> {:ok, context} | {:error, any})

  @type t :: %Reactor{
          context: context,
          hooks: %{
            optional(:complete) => [complete_hook],
            optional(:error) => [error_hook],
            optional(:halt) => [halt_hook],
            optional(:init) => [init_hook]
          },
          id: any,
          inputs: [atom],
          intermediate_results: %{any => any},
          plan: nil | Graph.t(),
          undo: [{Step.t(), any}],
          return: any,
          state: state,
          steps: [Step.t()]
        }

  @doc false
  @spec is_reactor(any) :: Macro.t()
  defguard is_reactor(reactor) when is_struct(reactor, __MODULE__)

  @doc """
  Run a reactor.
  """
  @spec run(t | module, inputs, context_arg, options) :: {:ok, any} | {:error, any} | {:halted, t}
  def run(reactor, inputs \\ %{}, context \\ %{}, options \\ [])

  def run(reactor, inputs, context, options) when is_atom(reactor) do
    with Reactor <- reactor.spark_is() do
      run(reactor.reactor(), inputs, context, options)
    end
  rescue
    UndefinedFunctionError -> {:error, "Module `#{inspect(reactor)}` is not a Reactor module"}
  end

  def run(reactor, inputs, context, options)
      when is_reactor(reactor) and reactor.state in ~w[pending halted]a do
    Executor.run(reactor, inputs, context, options)
  end
end
