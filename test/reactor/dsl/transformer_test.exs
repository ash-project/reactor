# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.TransformerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Spark.{Dsl.Extension, Error.DslError}

  defmodule Noop do
    @moduledoc false
    use Reactor.Step

    def run(_, _, _), do: {:ok, :noop}
  end

  defmodule NoReturnReactor do
    @moduledoc false
    use Reactor

    step :a, Noop
  end

  describe "transform/1" do
    test "when the Reactor has no explicit return, it uses the last step" do
      assert :a = Extension.get_opt(NoReturnReactor, [:reactor], :return)
    end

    test "when the Reactor has a return that is unknown, it raises a DSL error" do
      assert_raise DslError, ~r/return value/i, fn ->
        defmodule InvalidReturnReactor do
          @moduledoc false
          use Reactor

          step :a, Noop

          return :b
        end
      end
    end

    test "when the Reactor has no steps, it raises a DSL error" do
      assert_raise DslError, ~r/no steps/i, fn ->
        defmodule EmptyReactor do
          @moduledoc false
          use Reactor
        end
      end
    end
  end
end
