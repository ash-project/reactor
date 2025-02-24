defmodule Reactor.Mermaid.Render.Argument do
  @moduledoc false
  import Reactor.Mermaid.Utils
  alias Reactor.Argument
  require Argument

  @doc false
  def to_mermaid(argument, options) when Argument.is_from_value(argument) do
    target_id =
      options
      |> Keyword.fetch!(:parent_step)
      |> Map.fetch!(:name)
      |> mermaid_id(:step)

    source_id =
      argument.source.value
      |> mermaid_id(:value)

    indentify(
      """
      #{source_id}{{"`#{md_escape(inspect(argument.source.value, pretty: true))}`"}}}
      #{do_argument_link(source_id, target_id, argument, options)}
      """,
      options
    )
  end

  def to_mermaid(argument, options) when Argument.is_from_input(argument) do
    target_id =
      options
      |> Keyword.fetch!(:parent_step)
      |> Map.fetch!(:name)
      |> mermaid_id(:step)

    source_id =
      argument.source.name
      |> mermaid_id(:input)

    source_id
    |> do_argument_link(target_id, argument, options)
    |> indentify(options)
  end

  def to_mermaid(argument, options) do
    target_id =
      options
      |> Keyword.fetch!(:parent_step)
      |> Map.fetch!(:name)
      |> mermaid_id(:step)

    source_id =
      argument.source.name
      |> mermaid_id(:step)

    source_id
    |> do_argument_link(target_id, argument, options)
    |> indentify(options)
  end

  defp do_argument_link(source_id, target_id, argument, options) do
    if options[:describe?] && is_binary(argument.description) do
      "#{source_id} -->|#{name(argument.name)} -- #{argument.description}|#{target_id}\n"
    else
      "#{source_id} -->|#{name(argument.name)}|#{target_id}\n"
    end
  end
end
