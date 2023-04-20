defmodule Reactor.Argument do
  @moduledoc """
  A step argument.
  """

  defstruct name: nil, source: nil, transform: nil

  alias Reactor.{Argument, Template}

  @type t :: %Argument{
          name: atom,
          source: Template.t(),
          transform: nil | (any -> any)
        }

  defguardp is_transform(fun)
            when is_function(fun, 1) or
                   (tuple_size(fun) == 3 and is_atom(elem(fun, 0)) and is_atom(elem(fun, 1)) and
                      is_list(elem(fun, 2)))

  defguardp maybe_transform(fun) when is_nil(fun) or is_transform(fun)

  @doc """
  Build an argument which refers to a reactor input with an optional
  transformation applied.

  ## Example

      iex> Argument.from_input(:argument_name, :input_name, &String.to_integer/1)

  """
  @spec from_input(atom, atom, nil | (any -> any)) :: Argument.t()
  def from_input(name, input_name, transform \\ nil)
      when is_atom(name) and is_atom(input_name) and maybe_transform(transform),
      do: %Argument{name: name, source: %Template.Input{name: input_name}, transform: transform}

  @doc """
  Build an argument which refers to the result of another step with an optional
  transformation applied.

  ## Example

      iex> Argument.from_input(:argument_name, :step_name, &Atom.to_string/1)

  """
  @spec from_result(atom, any, nil | (any -> any)) :: Argument.t()
  def from_result(name, result_name, transform \\ nil)
      when is_atom(name) and maybe_transform(transform),
      do: %Argument{name: name, source: %Template.Result{name: result_name}, transform: transform}

  @doc """
  Validate that the argument is an Argument struct.
  """
  defguard is_argument(argument) when is_struct(argument, __MODULE__)

  @doc """
  Validate that the argument refers to a reactor input.
  """
  defguard is_from_input(argument) when is_struct(argument.source, Template.Input)

  @doc """
  Validate that the argument refers to a step result.
  """
  defguard is_from_result(argument) when is_struct(argument.source, Template.Result)

  @doc """
  Validate that the argument has a transform.
  """
  defguard has_transform(argument) when is_transform(argument.transform)
end
