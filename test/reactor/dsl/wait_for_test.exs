# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.WaitForTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Mimic

  alias Example.Step.Doable
  alias Reactor.{Argument, Dsl, Template}

  describe "Reactor.Argument.Build.build/1" do
    test "it can build an argument" do
      assert {:ok, [%Argument{name: :_, source: %Template.Result{name: :marty}, transform: nil}]} =
               Argument.Build.build(%Dsl.WaitFor{names: [:marty], __identifier__: :marty})
    end
  end

  test "there can be multiple `wait_for` steps" do
    defmodule MultiWaitForReactor do
      @moduledoc false
      use Reactor

      step :a, Doable do
        argument :name, value(:a)
      end

      step :b, Doable do
        argument :name, value(:b)
      end

      step :c, Doable do
        argument :name, value(:c)
        wait_for [:a, :b]
      end
    end

    Doable
    |> expect(:run, 2, fn args, _, _ ->
      assert args.name in [:a, :b]
      {:ok, args.name}
    end)
    |> expect(:run, fn args, _, _ ->
      assert args.name == :c
      assert Map.keys(args) == [:name]
      {:ok, :c}
    end)

    Reactor.run(MultiWaitForReactor)
  end
end
