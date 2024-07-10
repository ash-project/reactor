defmodule Mix.Tasks.Reactor.Install do
  @moduledoc """
  Installs Reactor into a project. Should be called with `mix igniter.install reactor`.
  """
  alias Igniter.{Mix.Task, Project.Formatter}

  @shortdoc "Installs Reactor into a project."

  use Task

  @doc false
  @impl Task
  def igniter(igniter, argv) do
    igniter
    |> Formatter.import_dep(:reactor)
  end
end
