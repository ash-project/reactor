defmodule Reactor.Argument do
  @moduledoc """
  A step argument.
  """

  defstruct name: nil, source: nil, transform: nil

  alias Reactor.{Argument, Template}
  import Reactor.Template, only: :macros

  @type t :: %Argument{
          name: atom,
          source: Template.t(),
          transform: nil | (any -> any) | {module, keyword} | mfa
        }

  defguardp is_spark_fun_behaviour(fun)
            when tuple_size(fun) == 2 and is_atom(elem(fun, 0)) and is_list(elem(fun, 1))

  defguardp is_mfa(fun)
            when tuple_size(fun) == 3 and is_atom(elem(fun, 0)) and is_atom(elem(fun, 1)) and
                   is_list(elem(fun, 2))

  defguardp is_transform(fun)
            when is_function(fun, 1) or is_spark_fun_behaviour(fun) or is_mfa(fun)

  defguardp maybe_transform(fun) when is_nil(fun) or is_transform(fun)

  @doc """
  Build an argument which refers to a reactor input with an optional
  transformation applied.

  ## Example

      iex> Argument.from_input(:argument_name, :input_name, &String.to_integer/1)

  """
  @spec from_input(atom, atom, nil | (any -> any)) :: Argument.t()
  def from_input(name, input_name, transform \\ nil)
      when is_atom(name) and maybe_transform(transform),
      do: %Argument{name: name, source: %Template.Input{name: input_name}, transform: transform}

  @doc """
  Build an argument which refers to the result of another step with an optional
  transformation applied.

  ## Example

      iex> Argument.from_result(:argument_name, :step_name, &Atom.to_string/1)

  """
  @spec from_result(atom, any, nil | (any -> any)) :: Argument.t()
  def from_result(name, result_name, transform \\ nil)
      when is_atom(name) and maybe_transform(transform),
      do: %Argument{name: name, source: %Template.Result{name: result_name}, transform: transform}

  @doc """
  Build an argument which refers to a statically defined value.

  ## Example

      iex> Argument.from_value(:argument_name, 10)
  """
  @spec from_value(atom, any, nil | (any -> any)) :: Argument.t()
  def from_value(name, value, transform \\ nil) when is_atom(name) and maybe_transform(transform),
    do: %Argument{name: name, source: %Template.Value{value: value}, transform: transform}

  @doc """
  Build an argument which refers to to an element within a map step with an optional transformation applied.

  ## Example

      iex> Argument.from_element(:argument_name, &Atom.to_string/1)

  """
  @spec from_element(atom, atom, nil | (any -> any)) :: Argument.t()
  def from_element(name, element_name, transform \\ nil)
      when is_atom(name) and maybe_transform(transform),
      do: %Argument{
        name: name,
        source: %Template.Element{name: element_name},
        transform: transform
      }

  @doc """
  Build an argument directly from a template.

  ## Example

      iex> Argument.from_template(:argument_name, Reactor.Dsl.Argument.input(:input_name))

  """
  @spec from_template(atom, Template.t(), nil | (any -> any)) :: Argument.t()
  def from_template(name, template, transform \\ nil)
      when is_atom(name) and is_template(template) and maybe_transform(transform),
      do: %Argument{name: name, source: template, transform: transform}

  @doc """
  Set a sub-path on the argument.

  ## Example

      iex> Argument.from_value(:example, :value)
      ...> |> Argument.sub_path([:nested, :values])

  """
  @spec sub_path(Argument.t(), [any]) :: Argument.t()
  def sub_path(argument, sub_path),
    do: %{argument | source: %{argument.source | sub_path: sub_path}}

  @doc """
  Validate that the argument is an Argument struct.
  """
  defguard is_argument(argument) when is_struct(argument, __MODULE__)

  @doc """
  Validate that the argument refers to a reactor input.
  """
  defguard is_from_input(argument)
           when is_argument(argument) and is_input_template(argument.source)

  @doc """
  Validate that the argument refers to a step result.
  """
  defguard is_from_result(argument)
           when is_argument(argument) and is_result_template(argument.source)

  @doc """
  Validate that the argument contains a static value.
  """
  defguard is_from_value(argument)
           when is_argument(argument) and is_value_template(argument.source)

  @doc """
  Validate that the argument contains an element.
  """
  defguard is_from_element(argument)
           when is_argument(argument) and is_element_template(argument.source)

  @doc """
  Validate that the argument has a transform.
  """
  defguard has_transform(argument) when is_transform(argument.transform)

  @doc """
  Validate that the argument source has a sub_path
  """
  defguard has_sub_path(argument)
           when is_list(argument.source.sub_path) and argument.source.sub_path != []
end
