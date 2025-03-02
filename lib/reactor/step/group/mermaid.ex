defmodule Reactor.Step.Group.Mermaid do
  @moduledoc """
  Mermaid rendering for `group` steps.
  """

  alias Reactor.Mermaid.{Node, Reactor, Utils}
  import Utils

  @doc false
  def to_mermaid(step, reactor, options) do
    with {:ok, sub_graph} <- Reactor.to_mermaid(reactor, options),
         {:ok, node} <- describe_step(step, options) do
      inner_return_id = mermaid_id(reactor.id, :return)

      links =
        reactor.inputs
        |> Enum.map(fn input ->
          [node.id, "-->", mermaid_id({reactor.id, input}, :input), "\n"]
        end)
        |> Enum.concat([inner_return_id, "-->", node.id, "\n"])

      {:ok, %{node | post: [sub_graph, node.post, links]}}
    end
  end

  defp describe_step(%{impl: {module, opts}} = step, options) do
    id = mermaid_id({options[:reactor_id], step.name}, :step)

    content =
      if options[:describe?] do
        functions =
          opts
          |> Keyword.take([:before, :after])
          |> Enum.sort_by(&elem(&1, 0))
          |> Enum.reject(&is_nil(elem(&1, 1)))
          |> Enum.map(fn {name, fun} ->
            [
              "- #{name}: _",
              md_escape(inspect(fun)),
              "_"
            ]
          end)
          |> Enum.intersperse(["\n"])

        [
          id,
          "[\"`**",
          md_escape(name(step.name)),
          " \\(",
          inspect(module),
          "\\)**\n",
          functions,
          if(step.description, do: ["\n", md_escape(step.description)], else: []),
          "`\"]\n"
        ]
      else
        [
          id,
          "[\"",
          name(step.name),
          "(",
          inspect(module),
          ")\"]\n"
        ]
      end

    {:ok, %Node{id: id, pre: content}}
  end
end
