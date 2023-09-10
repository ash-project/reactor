defmodule Reactor.Dsl.CollectTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Noop do
    @moduledoc false
    use Reactor.Step

    def run(_, context, _), do: {:ok, context.current_step.name}
  end

  defmodule CollectTransformReactor do
    @moduledoc false
    use Reactor

    input :organisation
    input :repository

    collect :latest_release_uri do
      argument :org, input(:organisation)
      argument :repo, input(:repository)
      transform &__MODULE__.do_transform/1
    end

    def do_transform(inputs) do
      %{uri: "https://api.github.com/repos/#{inputs.org}/#{inputs.repo}/releases/latest"}
    end
  end

  test "it works" do
    assert {:ok, result} =
             Reactor.run(CollectTransformReactor, %{
               organisation: "ash-project",
               repository: "reactor"
             })

    assert result.uri == "https://api.github.com/repos/ash-project/reactor/releases/latest"
  end
end
