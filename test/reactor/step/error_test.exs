# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Step.ErrorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule ErrorStep do
    @moduledoc false
    use Reactor.Step

    @impl true
    def run(_argument, _context, _options) do
      raise "This step always returns an error"
    end
  end

  defmodule ErrorReactor do
    @moduledoc false
    use Reactor

    step :named_step, ErrorStep
  end

  defmodule AnonErrorReactor do
    @moduledoc false
    use Reactor

    step :step do
      run fn _, _ ->
        raise "This always returns an error"
      end
    end
  end

  test "it has stacktrace available in error" do
    {:error, %{errors: [%{stacktrace: stacktrace}]}} = Reactor.run(ErrorReactor, %{})
    [{ErrorStep, :run, 3, opts} | _] = stacktrace.stacktrace

    assert Keyword.get(opts, :line) == 15
    assert Keyword.get(opts, :file) == ~c"test/reactor/step/error_test.exs"
  end

  test "it has stacktrace available when running anonymous step" do
    {:error, %{errors: [%{stacktrace: stacktrace}]}} = Reactor.run(AnonErrorReactor, %{})
    [{AnonErrorReactor, _anon_fn_name, _arity, opts} | _] = stacktrace.stacktrace

    assert Keyword.get(opts, :line) == 32
    assert Keyword.get(opts, :file) == ~c"test/reactor/step/error_test.exs"
  end
end
