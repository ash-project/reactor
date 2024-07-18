defmodule Reactor.Dsl.Argument do
  @moduledoc """
  The struct used to store `argument` DSL entities.

  See `d:Reactor.step.argument`.
  """

  defstruct __identifier__: nil,
            name: nil,
            source: nil,
            transform: nil

  alias Reactor.{Argument, Dsl, Step, Template}

  @type t :: %Dsl.Argument{
          name: atom,
          source: Template.t(),
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

  ## Extracting nested values

  You can provide a list of keys to extract from a data structure, similar to
  `Kernel.get_in/2` with the condition that the input value is either a struct
  or implements the `Access` protocol.
  """
  @spec input(atom, [any]) :: Template.Input.t()
  def input(input_name, sub_path \\ [])

  def input(input_name, sub_path),
    do: %Template.Input{name: input_name, sub_path: List.wrap(sub_path)}

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

  ## Extracting nested values

  You can provide a list of keys to extract from a data structure, similar to
  `Kernel.get_in/2` with the condition that the result is either a struct or
  implements the `Access` protocol.
  """
  @spec result(atom, [any]) :: Template.Result.t()
  def result(step_name, sub_path \\ [])

  def result(step_name, sub_path),
    do: %Template.Result{name: step_name, sub_path: List.wrap(sub_path)}

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
  def value(value), do: %Template.Value{value: value}

  @doc ~S"""
  The `element` template helper for the Reactor DSL.

  ## Example

  ```elixir
  defmodule ExampleReactor do
    use Reactor

    input :numbers

    map :double_numbers do
      source input(:numbers)

      step :double do
        argument :number, element(:double_numbers)

        run fn args, _, _ ->
          {:ok, args.number * 2}
        end
      end

      return :double
    end
  end
  ```
  """
  @spec element(any, [any]) :: Template.Element.t()
  def element(name, sub_path \\ [])
  def element(name, sub_path), do: %Template.Element{name: name, sub_path: List.wrap(sub_path)}

  @doc false
  def __entity__,
    do: %Spark.Dsl.Entity{
      name: :argument,
      describe: """
      Specifies an argument to a Reactor step.

      Each argument is a value which is either the result of another step, or an input value.

      Individual arguments can be transformed with an arbitrary function before
      being passed to any steps.
      """,
      examples: [
        """
        argument :name, input(:name)
        """,
        """
        argument :year, input(:date, [:year])
        """,
        """
        argument :user, result(:create_user)
        """,
        """
        argument :user_id, result(:create_user) do
          transform & &1.id
        end
        """,
        """
        argument :user_id, result(:create_user, [:id])
        """,
        """
        argument :three, value(3)
        """
      ],
      args: [:name, {:optional, :source}],
      target: Dsl.Argument,
      identifier: :name,
      imports: [Dsl.Argument],
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: """
          The name of the argument which will be used as the key in the `arguments` map passed to the implementation.
          """
        ],
        source: [
          type: Template.type(),
          required: true,
          doc: """
          What to use as the source of the argument. See `Reactor.Dsl.Argument` for more information.
          """
        ],
        transform: [
          type: {:or, [{:spark_function_behaviour, Step, {Step.Transform, 1}}, nil]},
          required: false,
          default: nil,
          doc: """
          An optional transformation function which can be used to modify the argument before it is passed to the step.
          """
        ]
      ]
    }

  defimpl Argument.Build do
    def build(argument) do
      argument =
        argument
        |> Map.from_struct()
        |> Map.take(~w[name source transform]a)
        |> then(&struct(Argument, &1))

      {:ok, [argument]}
    end
  end
end
