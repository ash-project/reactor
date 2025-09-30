# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.InfoTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Builder, Info}

  describe "to_struct/1" do
    test "when passed a DSL module, it generates a Reactor struct" do
      assert {:ok, %Reactor{} = reactor} = Info.to_struct(Example.BasicReactor)
      assert reactor.id == Example.BasicReactor
      assert reactor.steps |> hd() |> Map.get(:name) == :verify
    end

    test "when passed a Reactor struct, it returns it unchanged" do
      reactor =
        Builder.new()
        |> Builder.add_input!(:age)
        |> Builder.add_input!(:country)
        |> Builder.add_step!(:verify, Example.BasicReactor.DrinkingAgeVerifier,
          age: {:input, :age},
          country: {:input, :country}
        )

      assert {:ok, ^reactor} = Info.to_struct(reactor)
    end
  end
end
