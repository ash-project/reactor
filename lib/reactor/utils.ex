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
end
