# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.AroundTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Noop do
    @moduledoc false
    use Reactor.Step

    def run(_, context, _), do: {:ok, context.current_step.name}
  end

  defmodule AroundReactor do
    @moduledoc false
    use Reactor

    around :group, &__MODULE__.do_around/4 do
      step :a, Noop

      step :b, Noop
    end

    def do_around(arguments, context, steps, callback) do
      steps = Enum.filter(steps, &(&1.name == :b))

      callback.(arguments, context, steps)
    end
  end

  test "it works" do
    assert {:ok, result} = Reactor.run(AroundReactor)
    assert result == %{b: :b}
  end
end
