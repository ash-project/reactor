# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Argument.BuildTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Argument, Template}

  describe "build/1 for `Reactor.Argument.t`" do
    test "it builds a `Reactor.Argument`" do
      argument = Argument.from_value(:name, :value)

      assert {:ok, [^argument]} = Argument.Build.build(argument)
    end
  end

  describe "build/1 for `Tuple`" do
    test "when given an input tuple it builds a `Reactor.Argument`" do
      assert {:ok, [%Argument{name: :name, source: %Template.Input{name: :source}}]} =
               Argument.Build.build({:name, {:input, :source}})
    end

    test "when given a result tuple it builds a `Reactor.Argument`" do
      assert {:ok, [%Argument{name: :name, source: %Template.Result{name: :source}}]} =
               Argument.Build.build({:name, {:result, :source}})
    end

    test "when given a value tuple it builds a `Reactor.Argument`" do
      assert {:ok, [%Argument{name: :name, source: %Template.Value{value: :value}}]} =
               Argument.Build.build({:name, :value})
    end

    test "when given another tuple it returns an error" do
      assert {:error, error} = Argument.Build.build({:marty})
      assert Exception.message(error) =~ ~r/non-argument value/i
    end
  end
end
