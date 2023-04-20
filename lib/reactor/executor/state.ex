defmodule Reactor.Executor.State do
  @moduledoc """
  Contains the reactor execution state.

  This is run-time only information.
  """

  defstruct current_tasks: %{},
            errors: [],
            halt_timeout: 5000,
            max_concurrency: nil,
            max_iterations: :infinity,
            retries: %{},
            timeout: 5000

  alias Reactor.Step

  @type t :: %__MODULE__{
          current_tasks: %{Task.t() => Step.t()},
          errors: [any],
          halt_timeout: pos_integer() | :infinity,
          max_concurrency: pos_integer(),
          max_iterations: pos_integer() | :infinity,
          retries: %{reference() => pos_integer()},
          timeout: pos_integer() | :infinity
        }

  @doc false
  @spec init(map) :: t
  def init(attrs \\ %{}) do
    attrs
    |> Map.put_new_lazy(:max_concurrency, &System.schedulers_online/0)
    |> then(&struct(__MODULE__, &1))
  end
end
