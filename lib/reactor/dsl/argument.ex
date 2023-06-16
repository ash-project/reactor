defmodule Reactor.Dsl.Argument do
  @moduledoc """
  The struct used to store argument DSL entities.
  """

  defstruct name: nil, source: nil, transform: nil, __identifier__: nil
  alias Reactor.{Argument, Dsl, Template}

  @type t :: %Dsl.Argument{
          name: atom,
          source: Template.Input.t() | Template.Result.t() | Template.Value.t(),
          transform: nil | (any -> any) | {module, keyword} | mfa,
          __identifier__: any
        }

  @doc ~S"""
  The `input` template helper for the Reactor DSL.

  ## Example

  ```elixir
  defmodule ExampleReactor do
    use Reactor

    input :name

    step :greet do
      # here: --------↓↓↓↓↓
      argument :name, input(:name)
      run fn
        %{name: nil}, _, _ -> {:ok, "Hello, World!"}
        %{name: name}, _, _ -> {:ok, "Hello, #{name}!"}
      end
    end
  end
  ```
  """
  @spec input(atom) :: Template.Input.t()
  def input(input_name) do
    %Template.Input{name: input_name}
  end

  @doc ~S"""
  The `result` template helper for the Reactor DSL.

  ## Example

  ```elixir
  defmodule ExampleReactor do
    use Reactor

    step :whom do
      run fn ->
        {:ok, Enum.random(["Marty", "Doc", "Jennifer", "Lorraine", "George", nil])}
      end
    end

    step :greet do
      # here: --------↓↓↓↓↓↓
      argument :name, result(:whom)
      run fn
        %{name: nil}, _, _ -> {:ok, "Hello, World!"}
        %{name: name}, _, _ -> {:ok, "Hello, #{name}!"}
      end
    end
  end
  ```
  """
  @spec result(atom) :: Template.Result.t()
  def result(link_name) do
    %Template.Result{name: link_name}
  end

  @doc ~S"""
  The `value` template helper for the Reactor DSL.

  ## Example

  ```elixir
  defmodule ExampleReactor do
    use Reactor

    input :number

    step :times_three do
      argument :lhs, input(:number)
      # here: -------↓↓↓↓↓
      argument :rhs, value(3)

      run fn args, _, _ ->
        {:ok, args.lhs * args.rhs}
      end
    end
  end
  ```
  """
  @spec value(any) :: Template.Value.t()
  def value(value) do
    %Template.Value{value: value}
  end

  defimpl Argument.Build do
    def build(argument) do
      argument =
        argument
        |> Map.from_struct()
        |> Map.take(~w[name source transform]a)
        |> then(&struct(Argument, &1))

      {:ok, argument}
    end
  end
end
