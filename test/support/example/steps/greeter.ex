# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Example.Step.Greeter do
  @moduledoc false
  use Reactor.Step

  def run(%{whom: nil}, _, _), do: {:ok, "Hello, World!"}
  def run(%{whom: whom}, _, _), do: {:ok, "Hello, #{whom}!"}
end
