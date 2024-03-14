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
  """

  defstruct context: %{},
            id: nil,
            inputs: [],
            intermediate_results: %{},
            middleware: [],
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

  @type t :: %Reactor{
          context: context,
          id: any,
          inputs: [atom],
          intermediate_results: %{any => any},
          middleware: [Reactor.Middleware.t()],
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
    if Spark.Dsl.is?(reactor, Reactor) do
      run(reactor.reactor(), inputs, context, options)
    else
      {:error,
       ArgumentError.exception(message: "Module `#{inspect(reactor)}` is not a Reactor module")}
    end
  end

  def run(reactor, inputs, context, options)
      when is_reactor(reactor) and reactor.state in ~w[pending halted]a do
    Executor.run(reactor, inputs, context, options)
  end
end
