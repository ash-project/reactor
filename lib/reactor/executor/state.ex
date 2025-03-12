defmodule Reactor.Executor.State do
  @moduledoc """
  Contains the reactor execution state.

  This is run-time only information.
  """

  @defaults %{
    async?: true,
    halt_timeout: 5000,
    max_iterations: :infinity,
    timeout: :infinity
  }

  defstruct async?: @defaults.async?,
            concurrency_key: nil,
            current_tasks: %{},
            errors: [],
            halt_timeout: @defaults.halt_timeout,
            max_concurrency: nil,
            max_iterations: @defaults.max_iterations,
            pool_owner: false,
            retries: %{},
            skipped: MapSet.new(),
            started_at: nil,
            timeout: @defaults.timeout

  alias Reactor.{Executor.ConcurrencyTracker, Step}

  @type t :: %__MODULE__{
          async?: boolean,
          concurrency_key: ConcurrencyTracker.pool_key(),
          current_tasks: %{Task.t() => Step.t()},
          errors: [any],
          halt_timeout: pos_integer() | :infinity,
          max_concurrency: pos_integer(),
          max_iterations: pos_integer() | :infinity,
          pool_owner: boolean,
          retries: %{reference() => pos_integer()},
          skipped: MapSet.t(),
          started_at: DateTime.t(),
          timeout: pos_integer() | :infinity
        }

  @doc false
  @spec init(map) :: t
  def init(attrs \\ %{}) do
    @defaults
    |> Map.merge(attrs)
    |> do_init()
  end

  defp do_init(attrs) do
    attrs
    |> maybe_set_max_concurrency()
    |> maybe_allocate_concurrency_pool()
    |> Map.put(:started_at, DateTime.utc_now())
    |> Map.delete(:parent_reactor)
    |> then(&struct!(__MODULE__, &1))
  end

  defp maybe_set_max_concurrency(attrs)
       when is_integer(attrs.max_concurrency) and attrs.max_concurrency > 0,
       do: attrs

  defp maybe_set_max_concurrency(attrs) when attrs.async? == false,
    do: Map.put(attrs, :max_concurrency, 0)

  defp maybe_set_max_concurrency(attrs),
    do: Map.put(attrs, :max_concurrency, System.schedulers_online())

  defp maybe_allocate_concurrency_pool(attrs) when is_reference(attrs.concurrency_key) do
    attrs
    |> Map.put(:pool_owner, false)
  end

  defp maybe_allocate_concurrency_pool(attrs) do
    attrs
    |> Map.put(:concurrency_key, ConcurrencyTracker.allocate_pool(attrs.max_concurrency))
    |> Map.put(:pool_owner, true)
  end
end
