defmodule Reactor.Step.Compose do
  @moduledoc """
  A built-in step which can embed one reactor inside another.

  This step calls `Reactor.run/3` on the inner reactor and returns it's result.
  Reactor will correctly share the concurrency availability over both the parent
  and child Reactors.
  """

  use Reactor.Step

  @doc false
  @impl true
  def run(arguments, context, options) do
    reactor = Keyword.fetch!(options, :reactor)

    sub_context =
      options
      |> Keyword.get(:context, [])
      |> then(&Map.take(context, &1))

    Reactor.run(reactor, arguments, sub_context,
      concurrency_key: context.concurrency_key,
      async?: options[:async?] || false
    )
  end
end
