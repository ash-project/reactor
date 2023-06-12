defmodule Reactor.Utils do
  @moduledoc false

  @doc """
  Recursively merge maps.
  """
  @spec deep_merge(map, map) :: map
  def deep_merge(lhs, rhs) when is_map(lhs) and is_map(rhs) do
    Map.merge(lhs, rhs, fn
      _key, lvalue, rvalue when is_map(lvalue) and is_map(rvalue) ->
        deep_merge(lvalue, rvalue)

      _key, _lvalue, rvalue ->
        rvalue
    end)
  end

  @doc """
  Append a non-nil value to the end of the enumerable.
  """
  @spec maybe_append(Enumerable.t(), any) :: Enumerable.t()
  def maybe_append(collection, nil), do: collection
  def maybe_append(collection, value), do: Enum.concat(collection, [value])

  @doc """
  Append a non-nil result of the callback function to the enumerable.
  """
  @spec maybe_append_result(Enumerable.t(), (() -> any)) :: Enumerable.t()
  def maybe_append_result(collection, callback) do
    case callback.() do
      nil -> collection
      value -> Enum.concat(collection, [value])
    end
  end

  @doc """
  A joiner that replaces the last join value with a different one.
  """
  @spec sentence(Enumerable.t(), (any -> binary), binary, binary) :: binary
  def sentence(enumerable, mapper \\ &"`#{&1}`", joiner \\ ", ", last_joiner \\ " or ")

  def sentence(enumerable, mapper, joiner, last_joiner),
    do:
      enumerable
      |> Enum.to_list()
      |> do_sentence([], mapper, joiner, last_joiner)

  defp do_sentence([], [], _, _, _), do: []
  defp do_sentence([value], [], mapper, _, _), do: [mapper.(value)]

  defp do_sentence([value], zipped, mapper, _joiner, last_joiner) do
    [mapper.(value), last_joiner | zipped]
    |> Enum.reverse()
    |> Enum.join()
  end

  defp do_sentence([head | tail], [], mapper, joiner, last_joiner),
    do: do_sentence(tail, [mapper.(head)], mapper, joiner, last_joiner)

  defp do_sentence([head | tail], zipped, mapper, joiner, last_joiner),
    do: do_sentence(tail, [mapper.(head), joiner | zipped], mapper, joiner, last_joiner)

  @doc """
  Perform a map over an enumerable provided that the mapper function continues
  to return ok tuples.
  """
  @spec map_while_ok(Enumerable.t(input), (input -> {:ok, output} | {:error, any}), boolean) ::
          {:ok, Enumerable.t(output)} | {:error, any}
        when input: any, output: any
  def map_while_ok(inputs, mapper, preserve_order? \\ false)

  def map_while_ok(inputs, mapper, false) when is_function(mapper, 1) do
    reduce_while_ok(inputs, [], fn input, acc ->
      case mapper.(input) do
        {:ok, value} -> {:ok, [value | acc]}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def map_while_ok(inputs, mapper, true) do
    case map_while_ok(inputs, mapper, false) do
      {:ok, outputs} -> {:ok, Enum.reverse(outputs)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Perform a reduction over an enumerable provided that the reduction function
  returns an ok tuple.
  """
  @spec reduce_while_ok(Enumerable.t(input), acc, (input, acc -> {:ok, acc} | {:error, any})) ::
          {:ok, acc} | {:error, any}
        when input: any, acc: any
  def reduce_while_ok(inputs, default \\ [], reducer) when is_function(reducer, 2) do
    Enum.reduce_while(inputs, {:ok, default}, fn input, {:ok, acc} ->
      case reducer.(input, acc) do
        {:ok, acc} -> {:cont, {:ok, acc}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @type argument_error :: %ArgumentError{
          __exception__: true,
          message: binary
        }

  @doc """
  A wrapper for defining an ArgumentError with a consistent error message format.
  """
  @spec argument_error(String.Chars.t(), String.Chars.t(), any) :: argument_error
  def argument_error(argument_name, reason, value) do
    message =
      case value do
        nil ->
          "`#{argument_name}` #{reason}"

        value ->
          """
          `#{argument_name}` #{reason}

          ## Value of `#{argument_name}`

          ```
          #{inspect(value)}
          ```
          """
      end

    ArgumentError.exception(message: message)
  end
end
