defmodule Reactor.Mermaid do
  @moduledoc """
  Converts Reactors and their related entities into a Mermaid diagram.
  """
  @options Spark.Options.new!(
             expand?: [
               type: :boolean,
               required: false,
               default: false,
               doc: "Whether or not to expand composed Reactors"
             ],
             describe?: [
               type: :boolean,
               required: false,
               default: false,
               doc: "Whether or not to include descriptions, if available"
             ],
             direction: [
               type: {:in, [:top_to_bottom, :bottom_to_top, :right_to_left, :left_to_right]},
               required: false,
               default: :top_to_bottom,
               doc: "The direction to render the flowchart"
             ],
             indent: [
               type: :non_neg_integer,
               required: false,
               default: 0,
               doc: "How much to indent the resulting mermaid"
             ]
           )

  @type options :: unquote(Spark.Options.option_typespec(@options))

  import __MODULE__.Utils

  @doc """
  Convert the Reactor into Mermaid.

  ## Options

  #{Spark.Options.docs(@options)}
  """
  @spec to_mermaid(module | Reactor.t(), options) :: {:ok, iodata()} | {:error, any}
  def to_mermaid(reactor, options \\ [])

  def to_mermaid(reactor, options) do
    with {:ok, options} <- Spark.Options.validate(options, @options) do
      do_to_mermaid(reactor, options)
    end
  end

  @doc """
  Convert the Reactor into Mermaid

  Raising version of `to_mermaid/2`
  """
  @spec to_mermaid!(module | Reactor.t(), options) :: iodata | no_return()
  def to_mermaid!(reactor, options \\ []) do
    case to_mermaid(reactor, options) do
      {:ok, iodata} -> iodata
      {:error, reason} when is_exception(reason) -> raise reason
      {:error, reason} -> raise RuntimeError, reason
    end
  end

  defp do_to_mermaid(reactor, options) when is_atom(reactor) do
    if Code.ensure_loaded?(reactor) && function_exported?(reactor, :spark_is, 0) &&
         reactor.spark_is() == Reactor do
      do_to_mermaid(reactor.reactor(), options)
    else
      {:error, ArgumentError.exception(message: "`reactor` argument is not a Reactor")}
    end
  end

  defp do_to_mermaid(reactor, options) when is_struct(reactor, Reactor) do
    with {:ok, reactor} <- Reactor.Planner.plan(reactor) do
      mermaid = __MODULE__.Render.to_mermaid(reactor, indent(options))
      {:ok, indentify([["flowchart #{direction(options[:direction])}\n"] | mermaid], options)}
    end
  end

  defp direction(:top_to_bottom), do: "TD"
  defp direction(:bottom_to_top), do: "BT"
  defp direction(:left_to_right), do: "LR"
  defp direction(:right_to_left), do: "RL"
end
