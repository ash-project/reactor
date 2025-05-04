if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Reactor.Install do
    @moduledoc """
    Installs Reactor into a project. Should be called with `mix igniter.install reactor`.
    """
    alias Igniter.{Mix.Task, Project.Formatter}

    @shortdoc "Installs Reactor into a project."

    use Task

    @doc false
    @impl Task
    def igniter(igniter) do
      igniter
      |> Formatter.import_dep(:reactor)
    end
  end
else
  defmodule Mix.Tasks.Reactor.Install do
    @moduledoc """
    Installs Reactor into a project. Should be called with `mix igniter.install reactor`.
    """
    @shortdoc "Installs Reactor into a project."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'reactor.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
