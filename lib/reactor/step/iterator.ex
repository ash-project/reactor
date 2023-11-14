defmodule Reactor.Step.Iterator do
  @moduledoc """
  A recursive step which emits values (and steps) into the reactor until there
  are no more values (or steps) to emit.

  ## Options

  - `initialiser`: Initialise iteration by returning a value which will be used
    as the initial state for the `generator` function.
  """

  alias Reactor.{Argument, Builder, Dsl.Iterate, Step, Template.Result}
  import Reactor.Utils
  use Step

  @typedoc """
  An element emitted by a generator.
  """
  @type element :: any

  @typedoc """
  The generator state.
  """
  @type generator_state :: any

  @typedoc """
  A function which returns the initial state of the generator state.

  Similar to `Stream.resource/3`'s `start_fun` the return value is passed into
  the `generator` the first time through.  Additionally, it may return extra
  steps to be emitted into a reactor.
  """
  @type initialiser ::
          (Reactor.inputs(), Reactor.context() ->
             {:ok, generator_state} | {:ok, generator_state, [Step.t()]} | {:error, any})
          | (Reactor.inputs() ->
               {:ok, generator_state} | {:ok, generator_state, [Step.t()]} | {:error, any})

  @typedoc """
  A function which generates the next value(s) to be emitted into the reactor.

  Returns a list of values and an updated generator state.  It's up to you how
  many elements you wish to return from this function, however the following
  guidelines may apply:

    - returning too few values will artificially limit the concurrency of the
      Reactor by forcing it to repeatedly call this step to generate new values.
    - returning too many values will likely introduce planning delays as the DAG
      is updated and dependencies recalculated.

  Note that the `:halt` tuple does not halt the Reactor, but halts iteration.
  """
  @type generator ::
          (generator_state, Reactor.context() ->
             {:cont, [element], generator_state}
             | {:halt, generator_state}
             | {:error, any})
          | (generator_state ->
               {:cont, [element], generator_state}
               | {:halt, generator_state}
               | {:error, any})

  @typedoc """
  A function which generates additional steps for each element being emitted by
  the iterator.  It receives a template that refers to the individual element
  and can be used as an argument to your generated step.
  """
  @type step_generator ::
          (Result.t(), Reactor.context() -> {:ok, [Step.t()]} | {:error, any})
          | (Result.t() -> {:ok, [Step.t()]} | {:error, any})

  @typedoc """
  A function which is called when iteration is complete and can be used to clean
  up any resources or emit additional clean-up steps.
  """
  @type finaliser ::
          (generator_state, Reactor.context() -> :ok | {:ok, [Step.t()]} | {:error, any})
          | (generator_state -> :ok | {:ok, [Step.t()]} | {:error, any})

  @type options :: [
          {:elements, non_neg_integer()}
          | {:finaliser, finaliser}
          | {:generator, generator}
          | {:initialiser, initialiser}
          | {:iterations, non_neg_integer()}
          | {:iterator_state, :initialise | :generating | :finalising}
          | {:state_argument, atom}
          | {:step_generator, step_generator}
        ]

  @doc false
  @spec run(Reactor.inputs(), Reactor.context(), Keyword.t()) ::
          {:ok, any, [Step.t()]} | {:error, any}
  def run(arguments, context, options) do
    options = Keyword.update(options, :iterations, 1, &(&1 + 1))

    case Keyword.get(options, :iterator_state, :initialise) do
      :initialise ->
        call_initialiser(arguments, context, options)

      :generating ->
        call_generator(arguments, context, options)

      :finalising ->
        call_finaliser(arguments, context, options)

      other ->
        {:error, argument_error(:iterator_state, "Invalid state for iterator source", other)}
    end
  end

  defp call_initialiser(arguments, context, options) do
    options
    |> Keyword.fetch!(:initialiser)
    |> call_fun(arguments, context)
    |> handle_initialiser_result(arguments, context, options)
  end

  defp handle_initialiser_result({:ok, generator_state}, arguments, context, options),
    do: handle_initialiser_result({:ok, generator_state, []}, arguments, context, options)

  defp handle_initialiser_result({:error, reason}, _, _, _), do: {:error, reason}

  defp handle_initialiser_result({:ok, generator_state, new_steps}, arguments, context, options) do
    options =
      options
      |> Keyword.put(:iterator_state, :generating)
      |> Keyword.put(:elements, 0)
      |> Keyword.put_new(:state_argument, :state)

    # When there are no extra initialiser steps we just move straight on to
    # generating our first batch.
    if Enum.empty?(new_steps) do
      arguments =
        arguments
        |> Map.put(options[:state_argument], generator_state)

      call_generator(arguments, context, options)
    else
      {:ok, %{options[:state_argument] => generator_state}, [recurse(context, options)]}
    end
  end

  defp call_generator(arguments, context, options) do
    generator_state = Map.fetch!(arguments, options[:state_argument])

    options
    |> Keyword.fetch!(:generator)
    |> call_fun(generator_state, context)
    |> handle_generator_result(options, context)
  end

  defp handle_generator_result({:cont, elements, generator_state}, options, context) do
    start_idx = options[:elements]
    end_idx = start_idx + length(elements)
    initial_result = %{options[:state_argument] => generator_state}

    elements
    |> Enum.with_index(start_idx)
    |> reduce_while_ok({initial_result, []}, fn
      {element, idx}, {result, new_steps} ->
        with {:ok, additional_steps} <- maybe_generate_steps(options, idx, context) do
          {:ok,
           {Map.put(result, {:element, idx}, element), Enum.concat(additional_steps, new_steps)}}
        end
    end)
    |> case do
      {:ok, {result, new_steps}} ->
        options = Keyword.put(options, :elements, end_idx)

        {:ok, result, [recurse(context, options) | new_steps]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_generator_result({:halt, generator_state}, options, context) do
    options = Keyword.put(options, :iterator_state, :finalising)

    {:ok, %{options[:state_argument] => generator_state}, [recurse(context, options)]}
  end

  defp handle_generator_result({:error, reason}, _options, _context), do: {:error, reason}

  defp maybe_generate_steps(options, idx, context),
    do: maybe_generate_steps(options, idx, context, options[:step_generator])

  defp maybe_generate_steps(_options, _idx, _context, nil), do: {:ok, []}

  defp maybe_generate_steps(_options, idx, context, step_generator) do
    element_result = %Result{name: context.current_step.name, sub_path: [{:element, idx}]}

    call_fun(step_generator, element_result, context)
  end

  defp call_finaliser(arguments, context, options) do
    generator_state = Map.fetch!(arguments, options[:state_argument])
    finaliser = Keyword.fetch!(options, :finaliser)

    case call_fun(finaliser, generator_state, context) do
      :ok -> {:ok, :ok}
      {:ok, steps} when is_list(steps) -> {:ok, :ok, steps}
      {:error, reason} -> {:error, reason}
    end
  end

  defp recurse(context, options) do
    {:ok, recurse} =
      Builder.new_step(
        step_name(context, options[:iterations]),
        {__MODULE__, options},
        [
          {options[:state_argument],
           {:result, context.current_step.name, [options[:state_argument]]}}
        ],
        max_retries: 1,
        async?: context.current_step.async?
      )

    recurse
  end

  defp call_fun(fun, arguments, context) when is_function(fun, 2), do: fun.(arguments, context)
  defp call_fun(fun, arguments, _context) when is_function(fun, 1), do: fun.(arguments)

  # If someone provides an `mfa` with existing arguments we assume they should
  # be prepended to the call.
  defp call_fun({m, f, a}, arguments, context) do
    prepend_arity = length(a)

    case Enum.find(2..1, &function_exported?(m, f, &1 + prepend_arity)) do
      nil ->
        possible_arities = (prepend_arity + 1)..(prepend_arity + 2)

        {:error,
         "Unable to find function matching `#{inspect(m)}.#{f}/#{inspect(possible_arities)}"}

      2 ->
        apply(m, f, a ++ [arguments, context])

      1 ->
        apply(m, f, a ++ [arguments])
    end
  end

  defp step_name(context, iteration) when is_tuple(context.current_step.name),
    do: {elem(context.current_step.name, 0), iteration}

  defp step_name(context, iteration), do: {context.current_step.name, iteration}
end
