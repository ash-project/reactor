defmodule Reactor.Template.Element do
  @moduledoc """
  The `element` template.
  """

  defstruct name: nil, sub_path: []

  @type t :: %__MODULE__{name: atom, sub_path: Reactor.Template.sub_path()}

  @doc ~S"""
  The `element` template helper for the Reactor DSL.

  Elements are intermediate results within an iteration.

  ## Example

  ```elixir
  iterate :reverse_words do
    argument :words, input(:words)
    source_from :words, as: :word

    map do
      step :reverse_word do
        argument :word, element(:word)
        run &{:ok, &String.reverse(&1.word)}
      end
    end
  end
  ```
  """
  @spec element(atom, atom | Reactor.Template.sub_path()) :: t
  def element(name, sub_path \\ [])

  def element(name, sub_path),
    do: %__MODULE__{name: name, sub_path: List.wrap(sub_path)}
end
