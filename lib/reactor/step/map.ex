defmodule Reactor.Step.Map do
  @moduledoc """
  Repeatedly execute a group of steps by emitting values from a generator and
  consolidate their results with a reducer.

  This allows you to run steps over a list of elements without having to iterate
  the collection a number of times.

  ## Options

  * `initialiser` - a two-arity function which will be called to set up the
    iteration.  It should return some sort of state which when passed into the
    generator can provide the next value(s).
  * `generator` - a one-arity function which will be called with the iterator
    state which either returns the next value(s) or halts the iteration.
  * `finisher` - an optional one-arity function which can be used to handle the
    clean up of any resources used by the iterator (closing a file, for
    example).
  * `reducer` - an optional function which collects the results of the inner
    steps and reduces them into a single value.  The default function just
    collects them into a list.
  * `steps` - a list of steps to execute for each element.
  * `return` - an atom specifying which of the steps to use as the return value
    for each iteration.  If none is provided, then the last step will be used.
  * `accumulator` - an optional default value to use when starting the
    reduction.

  ## Example

  Iterating over a list and return the values as a list.

  ```elixir
  defmodule MapMyListReactor do
    use Reactor

    inputs :list

    map :make_shouty do
      argument :list, input(:list)
      initialise fn %{list: list}, _ ->
        {:ok, list}
      end

      generator fn
        [] -> {:halt, []}
        [head | tail] -> {:cont, [head], tail}
      end

      accumulator value([])

      reducer fn result, acc ->
        {:cont, [result | acc]}
      end

      return :shout

      step :shout do
        run fn %{value: value} ->
          {:ok, String.upcase(value)}
        end
      end
    end
  end
  ```
  """

  @typedoc "The state needed to generate from your iterator."
  @type iterator_state :: any

  @typedoc "An element emitted by your generator function."
  @type element :: any

  @typedoc "An accumulator used by the reducer"
  @type accumulator :: any

  @typedoc "The result of executing the contained steps upon the element"
  @type result :: any

  @typedoc """
  Your initialiser function.

  This receives the map arguments and the reactor context, from which you should
  be able to construct your iterator state.
  """
  @type initialiser ::
          (Reactor.inputs(), Reactor.context() -> {:ok, iterator_state} | {:error, any})

  @typedoc """
  Your generator function.

  This receives the iterator state and uses it to either emit new elements or
  halt iteration.

  When continuing iteration:

  - You **should** return a single element at a time from the generator.
  - You **can** return more than one element at a time and they will be buffered
    at the possible cost of more memory being consumed.
  - You **must** return at least one element, otherwise the map fail.
  """
  @type generator ::
          (iterator_state -> {:cont, [element], iterator_state} | {:halt, iterator_state})

  @typedoc """
  Your finisher function.

  This receives the iterator state after the generator function indicates to
  halt and can be used to release any resources being consumed by your iterator.
  """
  @type finisher :: (iterator_state -> :ok | {:error, any})

  @typedoc """
  Your reducer function.

  Receives a result from executing the nested steps for an element and reduce it
  into a single value.
  """
  @type reducer :: (result, accumulator -> {:cont, accumulator} | {:halt, accumulator})
end
