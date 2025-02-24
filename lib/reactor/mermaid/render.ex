defmodule Reactor.Mermaid.Render do
  @moduledoc """
  The behaviour for converting items into [Mermaid](https://mermaid.js.org/) charts.

  Don't call this behaviour directly, instead use it via `Reactor.Mermaid`.
  """

  @doc """
  Convert something item into Mermaid

  Options will have previously been validated by `Reactor.Mermaid.to_mermaid/2`.
  """
  @callback to_mermaid(module | struct, Reactor.Mermaid.options()) :: iodata() | no_return

  @doc """
  Convert something item into Mermaid

  Options will have previously been validated by `Reactor.Mermaid.to_mermaid/2`.
  """
  @spec to_mermaid(module | struct, Reactor.Mermaid.options()) :: iodata() | no_return
  def to_mermaid(module, options) when is_atom(module) do
    if Spark.implements_behaviour?(module, __MODULE__) do
      module.to_mermaid(module, options)
    else
      raise ArgumentError,
            "module `#{module}` does not implement the `#{inspect(__MODULE__)}` behaviour"
    end
  end

  def to_mermaid(struct, options) when is_struct(struct) do
    module = struct.__struct__

    if Spark.implements_behaviour?(module, __MODULE__) do
      module.to_mermaid(struct, options)
    else
      raise ArgumentError,
            "module `#{module}` does not implement the `#{inspect(__MODULE__)}` behaviour"
    end
  end
end
