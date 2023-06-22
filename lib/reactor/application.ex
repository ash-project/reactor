defmodule Reactor.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    [
      {PartitionSupervisor, child_spec: Task.Supervisor, name: Reactor.TaskSupervisor},
      Reactor.Executor.ConcurrencyTracker
    ]
    |> Supervisor.start_link(strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end
