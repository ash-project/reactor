defmodule Reactor.Step.Transform do
  @moduledoc """
  The built-in step for executing input and argument transformations.

  This step assumes that it is being executed as per `:spark_function_behaviour`
  semantics.
  """

  alias Reactor.Step
  use Step

  @doc false
  @impl true
  @spec run(Reactor.inputs(), Reactor.context(), keyword) :: {:ok | :error, any}
  def run(arguments, _context, options) do
    case Map.fetch(arguments, :value) do
      {:ok, value} -> do_transform(value, options)
      :error -> {:error, ArgumentError.exception("The `value` argument is missing")}
    end
  end

  defp do_transform(value, opts) do
    case Keyword.pop(opts, :fun) do
      {fun, _opts} when is_function(fun, 1) ->
        {:ok, fun.(value)}

      {fun, opts} when is_function(fun, 2) ->
        {:ok, fun.(value, opts)}

      {{m, f, a}, _opts} when is_atom(m) and is_atom(f) and is_list(a) ->
        {:ok, apply(m, f, [value | a])}

      {nil, opts} ->
        raise "Invalid options given to `run/3` callback: `#{inspect(opts)}`."
    end
  rescue
    error -> {:error, error}
  end
end
