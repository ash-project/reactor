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

  alias Reactor.{Argument, Step, Template}
  import Argument, only: :macros
  import Reactor, only: :macros
  import Reactor.Utils

  defguardp is_mfa(mfa)
            when tuple_size(mfa) == 2 and is_atom(elem(mfa, 0)) and
                   is_list(elem(mfa, 1))

  @type step_options :: [async? | max_retries() | arguments_transform | context]

  @typedoc "Should the step be run asynchronously?"
  @type async? :: {:async?, boolean}

  @typedoc "How many times is the step allowed to retry?"
  @type max_retries :: {:max_retries, :infinity | non_neg_integer()}

  @typedoc "Optionally transform all the arguments into new arguments"
  @type arguments_transform :: {:transform, nil | (any -> map) | {module | keyword} | mfa}

  @typedoc "Optional context which will be merged with the reactor context when calling this step."
  @type context :: Reactor.context()

  @type step_argument :: Argument.t() | {atom, {:input | :result, any}}
  @type impl :: module | {module, keyword}

  @doc """
  Build a new, empty Reactor.
  """
  @spec new :: Reactor.t()
  def new, do: %Reactor{}

  @doc """
  Add a named input to the Reactor.

  This both places the input in the Reactor for later input validation and adds
  steps to the Reactor which will emit and (possibly) transform the input.
  """
  @spec add_input(Reactor.t(), any, nil | (any -> any)) :: {:ok, Reactor.t()} | {:error, any}
  def add_input(reactor, name, transform \\ nil)

  def add_input(reactor, _name, _transform) when not is_reactor(reactor),
    do: {:error, ArgumentError.exception("`reactor`: not a Reactor")}

  def add_input(reactor, name, nil) do
    step = %Step{
      arguments: [],
      async?: true,
      impl: {Step.Input, name: name},
      name: {:input, name},
      max_retries: 0,
      ref: make_ref()
    }

    {:ok, %{reactor | inputs: [name | reactor.inputs], steps: [step | reactor.steps]}}
  end

  def add_input(reactor, name, transform)
      when is_function(transform, 1) or
             (tuple_size(transform) == 2 and is_atom(elem(transform, 0)) and
                is_list(elem(transform, 1))) do
    input_step = %Step{
      arguments: [],
      async?: true,
      impl: {Step.Input, name: name},
      name: {:raw_input, name},
      max_retries: 0,
      ref: make_ref()
    }

    transform_step = build_transform_step({:raw_input, name}, {:input, name}, transform)

    {:ok,
     %{
       reactor
       | inputs: [name | reactor.inputs],
         steps: [input_step, transform_step | reactor.steps]
     }}
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
    do: {:error, ArgumentError.exception("`reactor`: not a Reactor")}

  def add_step(_reactor, _name, _impl, arguments, _options) when not is_list(arguments),
    do: {:error, ArgumentError.exception("`arguments` is not a list")}

  def add_step(_reactor, _name, _impl, _arguments, options) when not is_list(options),
    do: {:error, ArgumentError.exception("`options` is not a list")}

  def add_step(reactor, name, impl, arguments, options) do
    with {:ok, arguments} <- assert_all_are_arguments(arguments),
         :ok <- assert_is_step_impl(impl),
         {:ok, arguments, argument_transform_steps} <-
           build_argument_transform_steps(arguments, name),
         {:ok, arguments, step_transform_step} <-
           maybe_build_step_transform_step(arguments, name, options[:transform]) do
      context =
        if step_transform_step do
          options
          |> Keyword.get(:context, %{})
          |> deep_merge(%{private: %{replace_arguments: :value}})
        else
          Keyword.get(options, :context, %{})
        end

      steps =
        [
          %Step{
            arguments: arguments,
            async?: Keyword.get(options, :async?, true),
            context: context,
            impl: impl,
            name: name,
            max_retries: Keyword.get(options, :max_retries, 100),
            ref: make_ref()
          }
        ]
        |> Enum.concat(argument_transform_steps)
        |> maybe_append(step_transform_step)
        |> Enum.concat(reactor.steps)

      {:ok, %{reactor | steps: steps}}
    end
  end

  @doc """
  Build a step which can be added to a reactor at runtime.

  Note that the built step doesn't support argument transformations - you should
  add an additional step to do the transformation needed (this is what
  `add_step/5` does anyway).
  """
  @spec new_step(name :: any, impl, [step_argument], step_options) ::
          {:ok, Step.t()} | {:error, any}
  def new_step(name, impl, arguments \\ [], options \\ [])

  def new_step(_name, _impl, arguments, _options) when not is_list(arguments),
    do: {:error, ArgumentError.exception("`arguments` is not a list")}

  def new_step(_name, _impl, _arguments, options) when not is_list(options),
    do: {:error, ArgumentError.exception("`options` is not a list")}

  def new_step(name, impl, arguments, options) do
    with {:ok, arguments} <- assert_all_are_arguments(arguments),
         :ok <- assert_is_step_impl(impl) do
      step = %Step{
        arguments: arguments,
        async?: Keyword.get(options, :async?, true),
        context: Keyword.get(options, :context, %{}),
        impl: impl,
        name: name,
        max_retries: Keyword.get(options, :max_retries, 100),
        ref: make_ref()
      }

      {:ok, step}
    end
  end

  @doc """
  Specify the return value of the Reactor.

  The return value must be the result of a completed step.
  """
  @spec return(Reactor.t(), any) :: {:ok, Reactor.t()} | {:error, any}
  def return(reactor, name) do
    step_names =
      reactor.steps
      |> Enum.map(& &1.name)

    if name in step_names do
      {:ok, %{reactor | return: name}}
    else
      {:error, ArgumentError.exception("`#{inspect(name)}` is not an existing step name")}
    end
  end

  defp assert_all_are_arguments(arguments) do
    Enum.reduce_while(arguments, {:ok, []}, fn
      argument, {:ok, arguments} when is_argument(argument) ->
        {:cont, {:ok, [argument | arguments]}}

      {name, {:input, source}}, {:ok, arguments} ->
        {:cont, {:ok, [Argument.from_input(name, source) | arguments]}}

      {name, {:result, source}}, {:ok, arguments} ->
        {:cont, {:ok, [Argument.from_result(name, source) | arguments]}}

      not_argument, _ ->
        {:halt,
         {:error,
          ArgumentError.exception(
            "Value `#{inspect(not_argument)}` is not a `Reactor.Argument` struct."
          )}}
    end)
  end

  defp assert_is_step_impl({impl, opts}) when is_list(opts), do: assert_is_step_impl(impl)

  defp assert_is_step_impl(impl) when is_atom(impl) do
    if Spark.implements_behaviour?(impl, Step) do
      :ok
    else
      {:error,
       ArgumentError.exception(
         "Module `#{inspect(impl)}` does not implement the `Reactor.Step` behaviour."
       )}
    end
  end

  defp build_argument_transform_steps(arguments, step_name) do
    arguments
    |> Enum.reduce_while({:ok, [], []}, fn
      argument, {:ok, arguments, steps}
      when is_from_input(argument) and has_transform(argument) ->
        step =
          build_transform_step(
            {:input, argument.source.name},
            {:transform, argument.name, :for, step_name},
            argument.transform
          )

        argument = %Argument{
          name: argument.name,
          source: %Template.Result{name: {:transform, argument.name, :for, step_name}}
        }

        {:cont, {:ok, [argument | arguments], [%{step | transform: nil} | steps]}}

      argument, {:ok, arguments, steps}
      when is_from_result(argument) and has_transform(argument) ->
        step =
          build_transform_step(
            argument.source.name,
            {:transform, argument.name, :for, step_name},
            argument.transform
          )

        argument = %Argument{
          name: argument.name,
          source: %Template.Result{name: {:transform, argument.name, :for, step_name}}
        }

        {:cont, {:ok, [argument | arguments], [%{step | transform: nil} | steps]}}

      argument, {:ok, arguments, steps} when is_from_input(argument) ->
        argument = %{argument | source: %Template.Result{name: {:input, argument.source.name}}}

        {:cont, {:ok, [argument | arguments], steps}}

      argument, {:ok, arguments, steps} when is_from_result(argument) ->
        {:cont, {:ok, [argument | arguments], steps}}
    end)
  end

  defp maybe_build_step_transform_step(arguments, _name, nil), do: {:ok, arguments, nil}

  defp maybe_build_step_transform_step(arguments, name, transform)
       when is_function(transform, 1),
       do: maybe_build_step_transform_step(arguments, name, {Step.TransformAll, fun: transform})

  defp maybe_build_step_transform_step(arguments, name, transform) do
    step = %Step{
      arguments: arguments,
      async?: true,
      impl: transform,
      name: {:transform, :for, name},
      max_retries: 0,
      ref: make_ref()
    }

    {:ok, [Argument.from_result(:value, step.name)], step}
  end

  defp build_transform_step(input_name, step_name, transform) when is_function(transform, 1),
    do: build_transform_step(input_name, step_name, {Step.Transform, fun: transform})

  defp build_transform_step(input_name, step_name, transform) when is_mfa(transform) do
    %Step{
      arguments: [
        %Argument{
          name: :value,
          source: %Template.Result{name: input_name}
        }
      ],
      async?: true,
      impl: transform,
      name: step_name,
      max_retries: 0,
      ref: make_ref()
    }
  end
end
