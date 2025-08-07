defmodule Reactor.Step.Compose do
  @moduledoc """
  A built-in step which can embed one reactor inside another.

  This step calls `Reactor.run/3` on the inner reactor and returns it's result.
  Reactor will correctly share the concurrency availability over both the parent
  and child Reactors.
  """

  use Reactor.Step
  @behaviour Reactor.Mermaid

  @doc false
  @impl true
  def run(arguments, context, options) do
    reactor = Keyword.fetch!(options, :reactor)
    allow_async? = Keyword.get(options, :allow_async?, true)

    # Child reactor can only run async if both parent allows async AND allow_async? is true
    # Use the context.async? field which contains the parent reactor's async state
    parent_async? = Map.get(context, :async?, true)
    child_async? = parent_async? and allow_async?

    Reactor.run(reactor, arguments, context,
      concurrency_key: context.concurrency_key,
      async?: child_async?
    )
  end

  @doc false
  @impl true
  def to_mermaid(step, options),
    do: __MODULE__.Mermaid.to_mermaid(step, options)
end
