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
    case Keyword.fetch!(options, :run) do
      fun when is_function(fun, 1) ->
        fun.(arguments)

      fun when is_function(fun, 2) ->
        fun.(arguments, context)

      {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, [arguments, context] ++ a)
    end
  rescue
    error -> {:error, error}
  end

  @doc false
  @impl true
  @spec compensate(any, Reactor.inputs(), Reactor.context(), keyword) ::
          {:continue, any} | :ok | :retry
  def compensate(reason, arguments, context, options) do
    case Keyword.fetch(options, :compensate) do
      {:ok, fun} when is_function(fun, 1) ->
        fun.(reason)

      {:ok, fun} when is_function(fun, 2) ->
        fun.(reason, arguments)

      {:ok, fun} when is_function(fun, 3) ->
        fun.(reason, arguments, context)

      {:ok, {m, f, a}} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, [reason, arguments, context] ++ a)

      _ ->
        :ok
    end
  end

  @doc false
  @impl true
  @spec undo(any, Reactor.inputs(), Reactor.context(), keyword) :: :ok | :retry | {:error, any}
  def undo(value, arguments, context, options) do
    case Keyword.fetch(options, :undo) do
      {:ok, fun} when is_function(fun, 1) ->
        fun.(value)

      {:ok, fun} when is_function(fun, 2) ->
        fun.(value, arguments)

      {:ok, fun} when is_function(fun, 3) ->
        fun.(value, arguments, context)

      {:ok, {m, f, a}} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, [value, arguments, context] ++ a)

      _ ->
        :ok
    end
  end
end
