defmodule Reactor.Builder.Input do
  @moduledoc """
  Handle adding inputs to Reactors for the builder.

  You should not use this module directly, but instead use
  `Reactor.Builder.add_input/3`.
  """
  alias Reactor.{Argument, Step}
  import Reactor.Utils

  @doc """
  Add a named input to the reactor.
  """
  @spec add_input(Reactor.t(), any, nil | (any -> any) | {Step.step(), keyword}) ::
          {:ok, Reactor.t()} | {:error, any}
  def add_input(reactor, name, nil), do: {:ok, %{reactor | inputs: [name | reactor.inputs]}}

  def add_input(reactor, name, transform) when is_function(transform, 1),
    do: add_input(reactor, name, {Step.Transform, fun: transform})

  def add_input(reactor, name, transform)
      when tuple_size(transform) == 2 and is_atom(elem(transform, 0)) and
             is_list(elem(transform, 1)) do
    transform_step = %Step{
      arguments: [Argument.from_input(:value, name)],
      async?: true,
      impl: transform,
      name: {:__reactor__, :transform, :input, name},
      max_retries: 0,
      ref: make_ref()
    }

    {:ok, %{reactor | inputs: [name | reactor.inputs], steps: [transform_step | reactor.steps]}}
  end

  def add_input(_reactor, _name, transform),
    do: {:error, argument_error(:transform, "Invalid transform function", transform)}
end
