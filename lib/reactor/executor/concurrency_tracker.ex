defmodule Reactor.Executor.ConcurrencyTracker do
  @moduledoc """
  Manage shared concurrency pools for multiple Reactors.

  When running a Reactor you can pass the `concurrency_key` option, which will
  cause the Reactor to use the specified pool to ensure that the combined
  Reactors never exceed the pool's available concurrency limit.

  This avoids nested Reactors spawning too many workers and thrashing the
  system.
  """

  use GenServer

  @type pool_key :: reference()

  @doc false
  @spec start_link(any) :: GenServer.on_start()
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc false
  @impl true
  @spec init(any) :: {:ok, atom | :ets.tid()}
  def init(_) do
    table = :ets.new(__MODULE__, ~w[set named_table public]a)
    {:ok, table}
  end

  @doc false
  @impl true
  def handle_cast({:monitor, pid}, table) do
    Process.monitor(pid)
    {:noreply, table}
  end

  @doc false
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, table) do
    :ets.select_delete(table, [{{:_, :_, :_, :"$1"}, [], [{:==, :"$1", pid}]}])
    {:noreply, table}
  end

  @doc """
  Allocate a new concurrency pool and set the maximum limit.
  """
  @spec allocate_pool(non_neg_integer) :: pool_key
  def allocate_pool(concurrency_limit) do
    key = make_ref()
    caller = self()
    :ets.insert(__MODULE__, {key, concurrency_limit, concurrency_limit, caller})
    GenServer.cast(__MODULE__, {:monitor, caller})
    key
  end

  @doc """
  Release the concurrency pool.

  This deletes the pool, however doesn't affect any processes currently using
  it.  No more resources can be acquired by users of the pool key.
  """
  @spec release_pool(pool_key) :: :ok
  def release_pool(pool_key) do
    :ets.delete(__MODULE__, pool_key)
    :ok
  end

  @doc """
  Release a concurrency allocation back to the pool.
  """
  @spec release(pool_key) :: :ok
  def release(key) do
    :ets.select_replace(__MODULE__, [
      {{:"$1", :"$2", :"$3", :"$4"},
       [{:andalso, {:"=<", {:+, :"$2", 1}, :"$3"}, {:==, :"$1", key}}],
       [{{:"$1", {:+, :"$2", 1}, :"$3", :"$4"}}]}
    ])

    :ok
  end

  @doc """
  Attempt to acquire a concurrency allocation from the pool.

  Returns `:ok` if the allocation was successful, otherwise `:error`.
  """
  @spec acquire(pool_key) :: :ok | :error
  def acquire(key) do
    __MODULE__
    |> :ets.select_replace([
      {{:"$1", :"$2", :"$3", :"$4"}, [{:andalso, {:>=, {:-, :"$2", 1}, 0}, {:==, :"$1", key}}],
       [{{:"$1", {:-, :"$2", 1}, :"$3", :"$4"}}]}
    ])
    |> case do
      0 -> :error
      1 -> :ok
    end
  end

  @doc """
  Report the available and maximum concurrency for a pool.
  """
  @spec status(pool_key) :: {:ok, available, limit} | {:error, any}
        when available: non_neg_integer(), limit: pos_integer()
  def status(key) do
    __MODULE__
    |> :ets.lookup(key)
    |> case do
      [{_, available, limit, _}] -> {:ok, available, limit}
      [] -> {:error, "Unknown concurrency pool"}
    end
  end
end
