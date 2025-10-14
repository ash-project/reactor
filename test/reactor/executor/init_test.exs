# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Executor.InitTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Executor.Init
  alias Reactor.Builder
  use Mimic

  describe "init/4" do
    setup do
      reactor = Builder.new()
      {:ok, reactor: reactor}
    end

    test "when the reactor argument is not a reactor struct it returns an error" do
      assert {:error, error} = init(URI.decode("http://mr.fusion"), [], [], [])
      assert Exception.message(error) =~ "not a Reactor"
    end

    test "when the inputs cannot be converted into a map it returns an error", %{reactor: reactor} do
      assert {:error, error} = init(reactor, [:wat], [], [])
      assert Exception.message(error) =~ "cannot be converted into a map"
    end

    test "when one of the reactor's inputs is missing it returns an error", %{
      reactor: reactor
    } do
      {:ok, reactor} = Builder.add_input(reactor, :hello, nil)
      assert {:error, error} = init(reactor, [], [], [])
      assert Exception.message(error) =~ "missing the following inputs"
    end

    test "when passed extra input it ignores them", %{reactor: reactor} do
      assert {:ok, reactor, _state} = init(reactor, [hello: :marty], [], [])
      refute Map.has_key?(reactor.context.private.inputs, :hello)
    end

    test "when the context cannot be converted into a map it returns an error", %{
      reactor: reactor
    } do
      assert {:error, error} = init(reactor, [], [:wat], [])
      assert Exception.message(error) =~ "cannot be converted into a map"
    end

    test "the context argument is merged into the reactor's context", %{reactor: reactor} do
      assert {:ok, reactor, _state} = init(reactor, [], [hello: :marty], [])
      assert reactor.context.hello == :marty
    end

    test "when the options cannot be converted into a map it returns an error", %{
      reactor: reactor
    } do
      assert {:error, error} = init(reactor, [], [], [:wat])
      assert Exception.message(error) =~ "cannot be converted into a map"
    end
  end
end
