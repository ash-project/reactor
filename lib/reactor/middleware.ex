defmodule Reactor.Middleware do
  @moduledoc """
  The Middleware behaviour.

  By implementing this behaviour you can modify the internal state of the
  Reactor during startup, execution and shutdown.

  Middlewares can be added to the reactor either with the `middlewares` DSL
  section or by the `add_middleware/2`, etc, functions in `Reactor.Builder`.
  """

  @type t :: module

  @type context :: Reactor.context()
  @type result :: any
  @type error_or_errors :: Exception.t() | [Exception.t()]

  @doc """
  The complete callback will be called with the successful result of the
  Reactor.

  This gives you the opportunity to modify the return value or to perform clean
  up of any non-reactor-managed resources (eg notifications).

  Note that these callbacks are called in an arbitrary order meaning that the
  result value passed may have already been altered by another callback.

  If any callback returns an error then any remaining callbacks will not
  be called.
  """
  @callback complete(result, context) :: {:ok, result} | {:error, any}

  @doc """
  The error callback will be called the final error value(s) of the Reactor.

  This gives you the opportunity to modify the return value or to perform clean
  up of any non-reactor-managed resources (eg notifications).

  Note that these callbacks are called in an arbitrary order meaning that the
  error value passed may have already been altered by another callback.

  Here a return value of `:ok` will continue calls to other callbacks without
  modifying the error value.
  """
  @callback error(error_or_errors, context) :: :ok | {:error, any}

  @doc """
  The halt callback will be called with the Reactor context when halting.

  This allows you to clean up any non-reactor-managed resources or modify the
  context for later re-use by a future `init/1` callback.
  """
  @callback halt(context) :: {:ok, context} | {:error, any}

  @doc """
  The init callback will be called with the Reactor context when starting up.

  This gives you the opportunity to modify the context or to perform any
  initialisation of any non-reactor-managed resources (eg notifications).
  """
  @callback init(context) :: {:ok, context} | {:error, any}

  @optional_callbacks complete: 2, error: 2, halt: 1, init: 1

  defmacro __using__(_env) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end
end
