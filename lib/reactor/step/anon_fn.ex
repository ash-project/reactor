defmodule Reactor.Step.AnonFn do
  @moduledoc """
  The built-in step for executing in-line DSL anonymous functions.

  This step assumes that it is being called as per the
  `:spark_function_behaviour` semantics.
  """

  use Reactor.Step

  @doc false
  @impl true
  @spec run(Reactor.inputs(), Reactor.context(), keyword) :: {:ok | :error, any}
  def run(arguments, context, options) do
    case Keyword.pop(options, :fun) do
      {fun, _opts} when is_function(fun, 2) ->
        fun.(arguments, context)

      {fun, opts} when is_function(fun, 3) ->
        fun.(arguments, context, opts)

      {{m, f, a}, opts} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, [arguments | [context | [opts | a]]])

      {nil, opts} ->
        raise ArgumentError,
          message: "Invalid options given to `run/3` callback: `#{inspect(opts)}`"
    end
  rescue
    error -> {:error, error}
  end
end
