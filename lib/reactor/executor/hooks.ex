defmodule Reactor.Executor.Hooks do
  @moduledoc """
  Handles the execution of reactor lifecycle hooks.
  """
  alias Reactor.Utils

  @doc "Run the init hooks collecting the new context as it goes"
  @spec init(Reactor.t(), Reactor.context()) :: {:ok, Reactor.context()} | {:error, any}
  def init(reactor, context) do
    reactor.hooks
    |> Map.get(:init, [])
    |> Utils.reduce_while_ok(context, &run_context_hook(&1, &2, :init))
  end

  @doc "Run the halt hooks collecting the new context as it goes"
  @spec halt(Reactor.t(), Reactor.context()) :: {:ok, Reactor.context()} | {:error, any}
  def halt(reactor, context) do
    reactor.hooks
    |> Map.get(:halt, [])
    |> Utils.reduce_while_ok(context, &run_context_hook(&1, &2, :halt))
  end

  @doc "Run the completion hooks allowing the result to be replaced"
  @spec complete(Reactor.t(), any, Reactor.context()) :: {:ok, any} | {:error, any}
  def complete(reactor, result, context) do
    reactor.hooks
    |> Map.get(:complete, [])
    |> Utils.reduce_while_ok(result, &run_result_hook(&1, &2, context))
  end

  @doc "Run the error hooks allowing the error to be replaced"
  @spec error(Reactor.t(), any, Reactor.context()) :: :ok | {:error, any}
  def error(reactor, reason, context) do
    reactor.hooks
    |> Map.get(:error, [])
    |> Enum.reduce({:error, reason}, fn hook, {:error, reason} ->
      case run_error_hook(hook, reason, context) do
        :ok -> {:error, reason}
        {:error, new_reason} -> {:error, new_reason}
      end
    end)
  end

  defp run_context_hook({m, f, a}, context, _) do
    apply(m, f, a ++ [context])
  rescue
    error -> {:error, error}
  end

  defp run_context_hook(fun, context, _) when is_function(fun, 1) do
    fun.(context)
  rescue
    error -> {:error, error}
  end

  defp run_context_hook(fun, _context, :init),
    do: {:error, Utils.argument_error(:fun, "Not a valid initialiser hook function", fun)}

  defp run_context_hook(fun, _context, :halt),
    do: {:error, Utils.argument_error(:fun, "Not a valid halt hook function", fun)}

  defp run_result_hook({m, f, a}, result, context) do
    apply(m, f, a ++ [result, context])
  rescue
    error -> {:error, error}
  end

  defp run_result_hook(fun, result, context) when is_function(fun, 2) do
    fun.(result, context)
  rescue
    error -> {:error, error}
  end

  defp run_result_hook(fun, _result, _context),
    do: {:error, Utils.argument_error(:run, "Not a valid completion hook function", fun)}

  defp run_error_hook({m, f, a}, reason, context) do
    apply(m, f, a ++ [reason, context])
  rescue
    error -> {:error, error}
  end

  defp run_error_hook(fun, reason, context) when is_function(fun, 2) do
    fun.(reason, context)
  rescue
    error -> {:error, error}
  end

  defp run_error_hook(fun, _reason, _context),
    do: {:error, Utils.argument_error(:run, "Not a valid error hook function", fun)}
end
