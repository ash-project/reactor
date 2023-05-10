defmodule Reactor.Step.Input do
  @moduledoc """
  A built-in step which emits a reactor input.
  """

  use Reactor.Step

  @doc false
  @impl true
  @spec can?(any) :: false
  def can?(_), do: false

  @doc false
  @impl true
  @spec run(Reactor.inputs(), Reactor.context(), keyword) :: {:ok | :error, any}
  def run(_arguments, context, options) do
    case Keyword.fetch(options, :name) do
      {:ok, name} ->
        with {:ok, private} <- Map.fetch(context, :private),
             {:ok, inputs} <- Map.fetch(private, :inputs),
             {:ok, value} <- Map.fetch(inputs, name) do
          {:ok, value}
        else
          :error ->
            {:error,
             ArgumentError.exception("Reactor is missing an input named `#{inspect(name)}`")}
        end

      :error ->
        {:error, ArgumentError.exception("Missing `:name` option in `Input` step")}
    end
  end
end
