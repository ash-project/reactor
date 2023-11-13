defmodule Reactor.Step.Iterator.Source do
  @moduledoc """
  A recursive step which emits values into the reactor until there are no more
  values to emit.
  """

  alias Reactor.{Argument, Builder, Dsl.Iterate.Source, Step}
  import Reactor.Utils
  use Step

  @type element :: any
  @type acc :: any

  @type initialiser ::
          (Reactor.inputs(), Reactor.context() ->
             {:ok, acc} | {:error, any})

  @type generator ::
          (acc, Reactor.context() ->
             {:cont, [element], acc}
             | {:cont, [element], acc, [Step.t()]}
             | {:halt, acc}
             | {:error, any})

  @type finaliser :: (acc, Reactor.context() -> :ok | {:error, any})

  @type options :: [
          {:state, :initialise | :generating | :finalising},
          {:initialiser, initialiser},
          {:generator, generator},
          {:finaliser, finaliser},
          {:acc, atom},
          {:elements, non_neg_integer()},
          {:iterations, non_neg_integer()}
        ]

  @doc false
  @spec run(Reactor.inputs(), Reactor.context(), Keyword.t()) ::
          {:ok, any, [Step.t()]} | {:error, any}
  def run(arguments, context, options) do
    options = Keyword.update(options, :iterations, 1, &(&1 + 1))

    case Keyword.get(options, :state, :initialise) do
      :initialise -> call_initialiser(arguments, context, options)
      :generating -> call_generator(arguments, context, options)
      :finalising -> call_finaliser(arguments, context, options)
      other -> {:error, argument_error(:state, "Invalid state for iterator source", other)}
    end
  end

  defp call_initialiser(arguments, context, options) do
    initialiser = Keyword.fetch!(options, :initialiser)

    case call_fun(initialiser, arguments, context) do
      {:ok, acc} ->
        options =
          options
          |> Keyword.put(:state, :generating)
          |> Keyword.put(:elements, 0)
          |> Keyword.put(:acc, :accumulator)

        arguments =
          arguments
          |> Map.put(options[:acc], acc)

        call_generator(arguments, context, options)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_generator(arguments, context, options) do
    acc = Map.fetch!(arguments, options[:acc])
    generator = Keyword.fetch!(options, :generator)

    case call_fun(generator, acc, context) do
      {:cont, elements, acc} ->
        start_idx = options[:elements]
        end_idx = start_idx + length(elements)

        result =
          elements
          |> Enum.with_index(start_idx)
          |> Enum.reduce(%{options[:acc] => acc}, fn {element, idx}, result ->
            Map.put(result, {:element, idx}, element)
          end)

        options = Keyword.put(options, :elements, end_idx)

        # figure out how to emit map/reduce steps for each element.

        {:ok, result, [recurse(context, options)]}

      {:halt, acc} ->
        options = Keyword.put(options, :state, :finalising)

        {:ok, %{options[:acc] => acc}, [recurse(context, options)]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_finaliser(arguments, context, options) do
    acc = Map.fetch!(arguments, options[:acc])
    finaliser = Keyword.fetch!(options, :finaliser)

    case call_fun(finaliser, acc, context) do
      :ok -> {:ok, :ok}
      {:error, reason} -> {:error, reason}
    end
  end

  defp recurse(context, options) do
    {:ok, recurse} =
      Builder.Step.new_step(
        step_name(context, options[:iterations]),
        {__MODULE__, options},
        [
          {options[:acc], {:result, context.current_step.name, [options[:acc]]}}
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
