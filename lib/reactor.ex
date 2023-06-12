defmodule Reactor do
  alias Reactor.{Dsl, Executor, Info, Planner, Step}

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

  <!--- ash-hq-hide-start --> <!--- -->

  ## DSL Documentation

  ### Index

  #{Spark.Dsl.Extension.doc_index(Dsl.sections())}

  ### Docs

  #{Spark.Dsl.Extension.doc(Dsl.sections())}

  <!--- ash-hq-hide-stop --> <!--- -->
  """

  defstruct context: %{},
            id: nil,
            inputs: [],
            intermediate_results: %{},
            plan: nil,
            return: nil,
            state: :pending,
            steps: [],
            undo: []

  use Spark.Dsl, default_extensions: [extensions: Dsl]

  @type context :: Enumerable.t({any, any})
  @type options ::
          Enumerable.t(
            {:max_concurrency, pos_integer()}
            | {:timeout, pos_integer() | :infinity}
            | {:max_iterations, pos_integer() | :infinity}
            | {:halt_timeout, pos_integer() | :infinity}
          )

  @type state :: :pending | :executing | :halted | :failed | :successful
  @type inputs :: %{optional(atom) => any}

  @type t :: %Reactor{
          context: context,
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
  @spec run(t | module, inputs, context, options) :: {:ok, any} | {:error, any} | {:halted, t}
  def run(reactor, inputs \\ %{}, context \\ %{}, options \\ [])

  def run(reactor, inputs, context, options) when is_atom(reactor) do
    with Reactor <- reactor.spark_is(),
         {:ok, reactor} <- Info.to_struct(reactor) do
      run(reactor, inputs, context, options)
    end
  rescue
    UndefinedFunctionError -> {:error, "Module `#{inspect(reactor)}` is not a Reactor module"}
  end

  def run(reactor, inputs, context, options)
      when is_reactor(reactor) and reactor.state in ~w[pending halted]a do
    with {:ok, reactor} <- maybe_plan(reactor) do
      Executor.run(reactor, inputs, context, options)
    end
  end

  defp maybe_plan(reactor) when reactor.steps == [], do: {:ok, reactor}
  defp maybe_plan(reactor), do: Planner.plan(reactor)
end
