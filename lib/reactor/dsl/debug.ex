defmodule Reactor.Dsl.Debug do
  @moduledoc """
  The `debug` DSL entity struct.

  See `d:Reactor.debug`.
  """

  defstruct __identifier__: nil,
            arguments: [],
            level: :debug,
            name: nil

  alias Reactor.{Dsl.Argument, Dsl.Build, Dsl.Debug}

  @type t :: %Debug{
          __identifier__: any,
          arguments: [Argument.t()],
          level: Logger.level(),
          name: atom
        }

  defimpl Build do
    alias Reactor.{Builder, Step}

    def build(debug, reactor) do
      Builder.add_step(
        reactor,
        debug.name,
        {Step.Debug, level: debug.level},
        debug.arguments,
        max_retries: 0,
        ref: :step_name
      )
    end

    def verify(_, _), do: :ok
    def transform(_, dsl_state), do: {:ok, dsl_state}
  end
end
