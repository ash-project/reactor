# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Example.ComplexReactor do
  @moduledoc false
  use Reactor

  defmodule Noop do
    use Reactor.Step

    @moduledoc false
    def run(_, _, _), do: {:ok, :noop}
  end

  input :i0 do
    transform &String.to_integer/1
  end

  input :i1

  step :l0, Noop do
    argument :a0 do
      source(input(:i0))
      transform &String.to_integer/1
    end
  end

  step :l0_5, Noop do
    argument :a0, input(:i1)
  end

  step :l1, Noop do
    argument :a1, result(:l0)
  end

  step :l2, Noop do
    argument :a2, result(:l0)
  end

  step :l3, Noop do
    argument :a3, result(:l0)
  end

  step :l4, Noop do
    argument :a4, result(:l0)
  end

  step :l5, Noop do
    argument :a5, result(:l0)
    async? false
  end
end
