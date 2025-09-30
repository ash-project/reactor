# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Example.Step.Doable do
  @moduledoc false
  use Reactor.Step

  def run(_, _, _), do: {:ok, __MODULE__}
end
