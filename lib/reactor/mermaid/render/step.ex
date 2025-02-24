defmodule Reactor.Mermaid.Render.Step do
  @moduledoc false
  import Reactor.Mermaid.Utils
  alias Reactor.Mermaid.Render

  @doc false
  def to_mermaid(step, options) do
    module = impl_for(step)
    arg_options = Keyword.put(options, :parent_step, step)
    arguments = Enum.map(step.arguments, &Render.to_mermaid(&1, arg_options))

    step =
      if Spark.implements_behaviour?(module, Render) do
        module.to_mermaid(step, options)
      else
        default_describe_step(step, module, options)
      end

    [arguments, step]
  end

  @doc false
  def default_describe_step(step, module, options) do
    if options[:describe?] do
      indentify(
        [
          mermaid_id(step.name, :step),
          "[\"`**",
          md_escape("#{name(step.name)}(#{inspect(module)})"),
          "**\n",
          md_escape(step.description),
          "`\"]\n"
        ],
        options
      )
    else
      indentify(
        [
          mermaid_id(step.name, :step),
          "[\"",
          name(step.name),
          "(",
          inspect(module),
          ")\"]\n"
        ],
        options
      )
    end
  end

  defp impl_for(%{impl: {module, _}}) when is_atom(module), do: module
  defp impl_for(%{impl: module}) when is_atom(module), do: module
end
