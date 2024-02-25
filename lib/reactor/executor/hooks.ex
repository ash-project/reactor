defmodule Reactor.Executor.Hooks do
  @moduledoc """
  Handles the execution of reactor middleware hooks.
  """
  alias Reactor.Utils

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
end
