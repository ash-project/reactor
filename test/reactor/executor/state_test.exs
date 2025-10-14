# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Executor.StateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.Executor.State

  describe "init/1" do
    test "when `max_concurrency` is not provided it defaults to the number of BEAM schedulers online" do
      assert State.init(%{}).max_concurrency == System.schedulers_online()
    end

    test "it returns a State struct" do
      state = State.init(%{})
      assert is_struct(state, State)
    end
  end
end
