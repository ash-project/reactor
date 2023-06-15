defmodule Reactor.Container do
  @moduledoc """

  """
  alias Reactor.Step

  @type container_name :: atom
  @type callback :: (Reactor.context(), [Step.t()] -> {:ok, map} | {:error, any})

  @callback before_steps(container_name, [Step.t()]) ::
              {:ok, Reactor.context()} | {:error, any}

  @callback after_steps(container_name, map) ::
              {:ok, Reactor.context()} | {:error, any}

  @callback around_steps(container_name, [Step.t()], callback) ::
              {:ok, any} | {:error, any}

  @optional_callbacks before_steps: 2, after_steps: 2, around_steps: 3

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      @after_verify unquote(__MODULE__).AfterVerify
    end
  end
end
