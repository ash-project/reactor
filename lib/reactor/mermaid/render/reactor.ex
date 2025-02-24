defmodule Reactor.Mermaid.Render.Reactor do
  @moduledoc false
  import Reactor.Mermaid.Utils

  @doc false
  def to_mermaid(reactor, options) do
    inputs = emit_inputs(reactor, indent(options))
    steps = emit_steps(reactor, indent(options))

    [
      indentify("subgraph #{inspect(reactor.id)}\n", options),
      inputs,
      steps,
      indentify("end", options)
    ]
  end

  defp emit_inputs(reactor, options) do
    Enum.map(reactor.inputs, fn input_name ->
      emit_input(reactor, input_name, options)
    end)
  end

  defp emit_input(reactor, input_name, options) do
    if options[:describe?] do
      indentify(
        [
          "#{mermaid_id(input_name, :input)}>\"`",
          "**Input #{input_name}**\n",
          md_escape(Map.get(reactor.input_descriptions, input_name)),
          "`\"]\n"
        ],
        options
      )
    else
      indentify(["#{mermaid_id(input_name, :input)}>\"Input #{input_name}\"]\n"], options)
    end
  end

  defp emit_steps(reactor, options) do
    reactor.plan
    |> Graph.vertices()
    |> Enum.map(&Reactor.Step.to_mermaid(&1, options))
  end
end
