defmodule Reactor.Executor.Hooks do
  @moduledoc """
  Handles the execution of reactor middleware hooks.
  """
  alias Reactor.{Middleware, Utils}
  require Logger

  @doc "Run the init hooks collecting the new context as it goes"
  @spec init(Reactor.t(), Reactor.context()) :: {:ok, Reactor.context()} | {:error, any}
  def init(reactor, context) do
    Utils.reduce_while_ok(reactor.middleware, context, fn middleware, context ->
      if function_exported?(middleware, :init, 1) do
        middleware.init(context)
      else
        {:ok, context}
      end
    end)
  end

  @doc "Run the halt hooks collecting the new context as it goes"
  @spec halt(Reactor.t(), Reactor.context()) :: {:ok, Reactor.context()} | {:error, any}
  def halt(reactor, context) do
    Utils.reduce_while_ok(reactor.middleware, context, fn middleware, context ->
      if function_exported?(middleware, :halt, 1) do
        middleware.halt(context)
      else
        {:ok, context}
      end
    end)
  end

  @doc "Run the completion hooks allowing the result to be replaced"
  @spec complete(Reactor.t(), any, Reactor.context()) :: {:ok, any} | {:error, any}
  def complete(reactor, result, context) do
    Utils.reduce_while_ok(reactor.middleware, result, fn middleware, result ->
      if function_exported?(middleware, :complete, 2) do
        middleware.complete(result, context)
      else
        {:ok, result}
      end
    end)
  end

  @doc "Run the error hooks allowing the error to be replaced"
  @spec error(Reactor.t(), any, Reactor.context()) :: {:error, any}
  def error(reactor, reason, context) do
    Enum.reduce(reactor.middleware, {:error, reason}, fn middleware, {:error, reason} ->
      with true <- function_exported?(middleware, :error, 2),
           {:error, reason} <- middleware.error(reason, context) do
        {:error, reason}
      else
        _ -> {:error, reason}
      end
    end)
  end

  @doc "Run any get_process_context hooks"
  @spec get_process_contexts(Reactor.t()) :: %{optional(Middleware.t()) => any}
  def get_process_contexts(reactor) do
    Enum.reduce(reactor.middleware, %{}, fn middleware, result ->
      if function_exported?(middleware, :get_process_context, 0) do
        result
        |> Map.put(middleware, middleware.get_process_context())
      else
        result
      end
    end)
  end

  @doc "Run set_process_context hooks given the result of `get_process_contexts/1`"
  @spec set_process_contexts(nil | %{optional(Middleware.t()) => any}) :: :ok
  def set_process_contexts(nil), do: :ok

  def set_process_contexts(contexts) do
    for {middleware, context} <- contexts do
      if function_exported?(middleware, :set_process_context, 1) do
        middleware.set_process_context(context)
      else
        Logger.warning(
          "Unable to set process context for middleware `#{inspect(middleware)}`: `set_process_context/1` is not defined."
        )
      end
    end

    :ok
  end
end
