defmodule Reactor.Builder.Argument do
  @moduledoc false

  import Reactor.Argument, only: :macros
  import Reactor.Utils
  alias Reactor.Argument

  @doc """
  Given a list of argument structs or keywords convert them all into Argument
  structs if possible, otherwise error.
  """
  @spec assert_all_are_arguments([Argument.t() | {atom, {:input | :result, any} | any}]) ::
          {:ok, [Argument.t()]} | {:error, Exception.t()}
  def assert_all_are_arguments(arguments) do
    map_while_ok(arguments, fn
      argument when is_argument(argument) -> {:ok, argument}
      {name, {:input, source}} -> {:ok, Argument.from_input(name, source)}
      {name, {:result, source}} -> {:ok, Argument.from_result(name, source)}
      {name, value} -> {:ok, Argument.from_value(name, value)}
      _ -> {:error, argument_error(:arguments, "contains a non-argument value.", arguments)}
    end)
  end
end
