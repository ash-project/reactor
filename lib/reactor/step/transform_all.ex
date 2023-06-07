defmodule Reactor.Step.TransformAll do
  @moduledoc """
  A built-in step which applies a transformation function to all it's arguments.

  The returned map is used as the arguments to the step, instead of the step's
  defined arguments.
  """

  use Reactor.Step
  alias Reactor.Step.Transform

  @doc false
  @impl true
  @spec run(Reactor.inputs(), Reactor.context(), keyword) :: {:ok | :error, any}
  def run(arguments, context, options) do
    case Transform.run(%{value: arguments}, context, options) do
      {:ok, result} when is_map(result) ->
        {:ok, result}

      {:ok, _other} ->
        {:error, "Step transformers must return a map to use as replacement arguments."}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
