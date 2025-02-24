defmodule Reactor.Mermaid.Utils do
  @moduledoc """
  Utilities for generating Mermaid.
  """

  @doc "Add one to the current indent level"
  @spec indent(Keyword.t()) :: Keyword.t()
  def indent(options) do
    indent = options[:indent] || 0
    Keyword.put(options, :indent, indent + 1)
  end

  @doc "Remove one from the current indent level"
  @spec dedent(Keyword.t()) :: Keyword.t() | no_return
  def dedent(options) do
    case options[:indent] do
      i when is_integer(i) and i > 0 -> Keyword.put(options, :indent, i - 1)
      _ -> raise "Cannot dedent into negative values"
    end
  end

  @doc "Indent the iodata correctly"
  @spec indentify(iodata, Keyword.t()) :: iodata
  def indentify(iodata, options) do
    indent_level = options[:indent] || 0

    if indent_level == 0 do
      iodata
    else
      indent = Enum.map(1..indent_level//1, fn _ -> "  " end)

      iodata
      |> IO.iodata_to_binary()
      |> do_indentify(indent)
    end
  end

  defp do_indentify(string, indent) do
    case String.split(string, ~r/[\r\n]/) do
      [""] ->
        []

      [single_line] ->
        [indent, single_line]

      [line, ""] ->
        [indent, line, "\n"]

      [head | tail] ->
        tail =
          tail
          |> List.wrap()
          |> Enum.map(&["\n", indent, &1])

        [indent, head, tail]
    end
  end

  @doc "Escape markdown as needed"
  def md_escape(nil), do: ""

  def md_escape(md) do
    md
    |> String.replace("\\", "\\\\")
    |> String.replace("`", "&#96;")
    |> String.replace("*", "\\*")
    |> String.replace("_", "\\_")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("<", "\\<")
    |> String.replace(">", "\\>")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace("#", "\\#")
    |> String.replace("+", "\\+")
    |> String.replace("-", "\\-")
    |> String.replace(".", "\\.")
    |> String.replace("!", "\\!")
    |> String.replace("|", "\\|")
  end

  @doc "Generate a mermaid ID for a term"
  @spec mermaid_id(any, String.Chars.t()) :: String.t()
  def mermaid_id(name, prefix) when is_atom(name) do
    charlist = Atom.to_charlist(name)

    if List.ascii_printable?(charlist) do
      "#{prefix}_#{name}"
    else
      "#{prefix}_#{:erlang.phash2(name)}"
    end
  end

  def mermaid_id(name, prefix) when is_binary(name) do
    charlist = String.to_charlist(name)

    if List.ascii_printable?(charlist) do
      "#{prefix}_#{name}"
    else
      "#{prefix}_#{:erlang.phash2(name)}"
    end
  end

  def mermaid_id(name, prefix), do: "#{prefix}_#{:erlang.phash2(name)}"

  @doc "Generate a name which can be used within a Mermaid node"
  def name(name) when is_binary(name) do
    if String.printable?(name) do
      name
    else
      inspect(name)
    end
  end

  def name(name) when is_atom(name) do
    name
    |> to_string()
    |> name()
  end

  def name(name), do: inspect(name)
end
