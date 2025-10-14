# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.FailTest do
  use ExUnit.Case, async: true

  alias Reactor.{Error, Error.Invalid.ForcedFailureError}

  defmodule FailReactor do
    @moduledoc false
    use Reactor

    flunk(:flunk, "Fail")
  end

  test "it returns an forced failure error" do
    assert {:error, error} = Reactor.run(FailReactor, [])

    assert is_exception(error)

    assert {:ok, error} = Error.fetch_error(error, ForcedFailureError)
    assert error.message == "Fail"
    assert error.arguments == %{}
    assert error.step_name == :flunk
  end
end
