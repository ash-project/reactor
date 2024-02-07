defmodule Reactor.Builder do
  @moduledoc """
  Build a new Reactor programmatically.

  You don't _have_ to use the Reactor DSL to create a Reactor.  The functions in
  this module allow you to define a Reactor programmatically.  This is
  especially useful if you need to create a reactor dynamically (maybe based on
  a UI such as [React Flow](https://reactflow.dev/)).

  ## Example

  ```elixir
  reactor = Builder.new()
  {:ok, reactor} = Builder.add_input(reactor, :name)
  argument = Argument.from_input(:name)
  {:ok, reactor} = Builder.add_step(reactor, :greet, [argument])
  {:ok, reactor} = Builder.return(reactor, :greet)
  ```
  """

  alias Reactor.{Argument, Builder, Step}
  import Reactor, only: :macros
  import Reactor.Utils

  @type step_options :: [async? | max_retries() | arguments_transform | context | ref]

  @typedoc "Should the step be run asynchronously?"
  @type async? :: {:async?, boolean | (keyword -> boolean)}

  @typedoc "How many times is the step allowed to retry?"
  @type max_retries :: {:max_retries, :infinity | non_neg_integer()}

  @typedoc "Optionally transform all the arguments into new arguments"
  @type arguments_transform ::
          {:transform,
           nil | (%{optional(atom) => any} -> %{optional(atom) => any}) | {module | keyword} | mfa}

  @type ref :: {:ref, :step_name | :make_ref}

  @typedoc "Optional context which will be merged with the reactor context when calling this step."
  @type context :: Reactor.context()

  @type step_argument :: Argument.t() | {atom, {:input | :result, any}}
  @type impl :: module | {module, keyword}

  @doc """
  Build a new, empty Reactor.

  Optionally an identifier for the Reactor. This is primarily used for recursive
  composition tracking.
  """
  @spec new(any) :: Reactor.t()
  def new(id \\ make_ref()),
    do: %Reactor{id: id, context: %{private: %{composed_reactors: MapSet.new([id])}}}

  @doc """
  Add a named input to the Reactor.

  This both places the input in the Reactor for later input validation and adds
  steps to the Reactor which will emit and (possibly) transform the input.
  """
  @spec add_input(Reactor.t(), any, nil | (any -> any)) :: {:ok, Reactor.t()} | {:error, any}
  def add_input(reactor, name, transform \\ nil)

  def add_input(reactor, _name, _transform) when not is_reactor(reactor),
    do: {:error, argument_error(:reactor, "not a Reactor", reactor)}

  def add_input(reactor, name, transform),
    do: Builder.Input.add_input(reactor, name, transform)

  @doc """
  Raising version of `add_input/2..3`.
  """
  @spec add_input!(Reactor.t(), any, nil | (any -> any)) :: Reactor.t() | no_return
  def add_input!(reactor, name, transform \\ nil)

  def add_input!(reactor, name, transform) do
    case add_input(reactor, name, transform) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Add a step to the Reactor.

  Add a new step to the Reactor.  Rewrites input arguments to use the result of
  the input steps and injects transformation steps as required.
  """
  @spec add_step(
          Reactor.t(),
          name :: any,
          impl,
          [step_argument],
          step_options
        ) :: {:ok, Reactor.t()} | {:error, any}

  def add_step(reactor, name, impl, arguments \\ [], options \\ [])

  def add_step(reactor, _name, _impl, _arguments, _options) when not is_reactor(reactor),
    do: {:error, argument_error(:reactor, "not a Reactor", reactor)}

  def add_step(_reactor, _name, _impl, arguments, _options) when not is_list(arguments),
    do: {:error, argument_error(:arguments, "not a list", arguments)}

  def add_step(_reactor, _name, _impl, _arguments, options) when not is_list(options),
    do: {:error, argument_error(:options, "not a list", options)}

  def add_step(reactor, name, impl, arguments, options),
    do: Builder.Step.add_step(reactor, name, impl, arguments, options)

  @doc """
  Raising version of `add_step/3..5`.
  """
  @spec add_step!(Reactor.t(), name :: any, impl, [step_argument], step_options) ::
          Reactor.t() | no_return
  def add_step!(reactor, name, impl, arguments \\ [], options \\ [])

  def add_step!(reactor, name, impl, arguments, options) do
    case add_step(reactor, name, impl, arguments, options) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Build a step which can be added to a reactor at runtime.

  Note that the built step doesn't support transformations - you should add an
  additional step to do the transformation needed (this is what `add_step/5`
  does anyway).
  """
  @spec new_step(any, impl, [step_argument], step_options) :: {:ok, Step.t()} | {:error, any}
  def new_step(name, impl, arguments \\ [], options \\ [])

  def new_step(_name, _impl, arguments, _options) when not is_list(arguments),
    do: {:error, argument_error(:arguments, "not a list", arguments)}

  def new_step(_name, _impl, _arguments, options) when not is_list(options),
    do: {:error, argument_error(:options, "not a list", options)}

  def new_step(name, impl, arguments, options),
    do: Builder.Step.new_step(name, impl, arguments, options)

  @doc """
  Raising version of `new_step/2..4`.
  """
  @spec new_step!(any, impl, [step_argument], step_options) :: Step.t() | no_return
  def new_step!(name, impl, arguments \\ [], options \\ [])

  def new_step!(name, impl, arguments, options) do
    case new_step(name, impl, arguments, options) do
      {:ok, step} -> step
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Specify the return value of the Reactor.

  The return value must be the name of a step.
  """
  @spec return(Reactor.t(), any) :: {:ok, Reactor.t()} | {:error, any}
  def return(reactor, name) do
    step_names =
      reactor.steps
      |> Enum.map(& &1.name)

    if name in step_names do
      {:ok, %{reactor | return: name}}
    else
      {:error, argument_error(:name, "not an existing step name.", name)}
    end
  end

  @doc """
  Raising version of `return/2`.
  """
  @spec return!(Reactor.t(), any) :: Reactor.t() | no_return
  def return!(reactor, name) do
    case return(reactor, name) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Compose another Reactor inside this one.

  Whenever possible this function will extract the steps from inner Reactor and
  place them inside the parent Reactor.  In order to achieve this the composer
  will rename the steps to ensure that there are no conflicts.

  If you're attempting to create a recursive Reactor (ie compose a Reactor
  within itself) then this will be detected and runtime composition will be used
  instead.  See `Reactor.Step.Compose` for more details.
  """
  @spec compose(Reactor.t(), atom, Reactor.t() | module, [step_argument]) ::
          {:ok, Reactor.t()} | {:error, any}
  def compose(reactor, _name, _inner_reactor, _arguments) when not is_reactor(reactor),
    do: {:error, argument_error(:reactor, "not a Reactor", reactor)}

  def compose(_reactor, name, _inner_reactor, _arguments) when not is_atom(name),
    do: {:error, argument_error(:name, "not an atom", name)}

  def compose(_reactor, _name, inner_reactor, _arguments)
      when not is_reactor(inner_reactor) and not is_atom(inner_reactor),
      do: {:error, argument_error(:inner_reactor, "not a Reactor", inner_reactor)}

  def compose(_reactor, _name, _inner_reactor, arguments) when not is_list(arguments),
    do: {:error, argument_error(:arguments, "not a list", arguments)}

  def compose(reactor, name, inner_reactor, arguments),
    do: Builder.Compose.compose(reactor, name, inner_reactor, arguments)

  @doc """
  Raising version of `compose/4`.
  """
  @spec compose!(Reactor.t(), atom, Reactor.t() | module, [step_argument]) ::
          Reactor.t() | no_return
  def compose!(reactor, name, inner_reactor, arguments) do
    case compose(reactor, name, inner_reactor, arguments) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Add an initialiser hook to the Reactor.
  """
  @spec on_init(Reactor.t(), Reactor.init_hook()) :: {:ok, Reactor.t()} | {:error, any}
  def on_init(reactor, {m, f, a}) when is_atom(m) and is_atom(f) and is_list(a),
    do: add_hook(reactor, :init, {m, f, a})

  def on_init(reactor, hook) when is_function(hook, 1),
    do: add_hook(reactor, :init, hook)

  def on_init(_reactor, hook),
    do: {:error, argument_error(:hook, "Not a valid initialisation hook", hook)}

  @doc """
  Raising version of `on_init/2`.
  """
  @spec on_init!(Reactor.t(), Reactor.init_hook()) :: Reactor.t() | no_return
  def on_init!(reactor, hook) do
    case on_init(reactor, hook) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Add an error hook to the Reactor.
  """
  @spec on_error(Reactor.t(), Reactor.init_hook()) :: {:ok, Reactor.t()} | {:error, any}
  def on_error(reactor, {m, f, a}) when is_atom(m) and is_atom(f) and is_list(a),
    do: add_hook(reactor, :error, {m, f, a})

  def on_error(reactor, hook) when is_function(hook, 2),
    do: add_hook(reactor, :error, hook)

  def on_error(_reactor, hook),
    do: {:error, argument_error(:hook, "Not a valid error hook", hook)}

  @doc """
  Raising version of `on_error/2`.
  """
  @spec on_error!(Reactor.t(), Reactor.init_hook()) :: Reactor.t() | no_return
  def on_error!(reactor, hook) do
    case on_error(reactor, hook) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Add a completion hook to the Reactor.
  """
  @spec on_complete(Reactor.t(), Reactor.complete_hook()) :: {:ok, Reactor.t()} | {:error, any}
  def on_complete(reactor, {m, f, a}) when is_atom(m) and is_atom(f) and is_list(a),
    do: add_hook(reactor, :complete, {m, f, a})

  def on_complete(reactor, hook) when is_function(hook, 2),
    do: add_hook(reactor, :complete, hook)

  def on_complete(_reactor, hook),
    do: {:error, argument_error(:hook, "Not a valid completion hook", hook)}

  @doc """
  Raising version of `on_complete/2`.
  """
  @spec on_complete!(Reactor.t(), Reactor.init_hook()) :: Reactor.t() | no_return
  def on_complete!(reactor, hook) do
    case on_complete(reactor, hook) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Add a halt hook to the Reactor.
  """
  @spec on_halt(Reactor.t(), Reactor.halt_hook()) :: {:ok, Reactor.t()} | {:error, any}
  def on_halt(reactor, {m, f, a}) when is_atom(m) and is_atom(f) and is_list(a),
    do: add_hook(reactor, :halt, {m, f, a})

  def on_halt(reactor, hook) when is_function(hook, 1),
    do: add_hook(reactor, :halt, hook)

  def on_halt(_reactor, hook),
    do: {:error, argument_error(:hook, "Not a valid completion hook", hook)}

  @doc """
  Raising version of `on_halt/2`.
  """
  @spec on_halt!(Reactor.t(), Reactor.init_hook()) :: Reactor.t() | no_return
  def on_halt!(reactor, hook) do
    case on_halt(reactor, hook) do
      {:ok, reactor} -> reactor
      {:error, reason} -> raise reason
    end
  end

  defp add_hook(reactor, type, hook) when is_reactor(reactor) do
    hooks =
      reactor.hooks
      |> Map.update(type, [hook], &Enum.concat(&1, [hook]))

    {:ok, %{reactor | hooks: hooks}}
  end

  defp add_hook(reactor, _, _), do: {:error, argument_error(:reactor, "not a Reactor", reactor)}
end
