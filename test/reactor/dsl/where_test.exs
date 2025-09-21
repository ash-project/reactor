# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.WhereTest do
  use ExUnit.Case, async: true

  defmodule ReplaceContentStep do
    @moduledoc false
    use Reactor.Step

    def run(args, _context, _options) do
      content = "Roads? Where we're going we don't need roads"
      File.write!(args.path, content)
      {:ok, content}
    end

    def undo(_value, _arguments, _context, _options) do
      raise "hell"
    end
  end

  defmodule PredicateReactor do
    @moduledoc false
    use Reactor

    input :path

    step :read, ReplaceContentStep do
      argument :path, input(:path)
      where(&File.exists?(&1.path))
    end

    return :read
  end

  defmodule FailingPredicateReactor do
    @moduledoc false
    use Reactor

    input :path

    step :read, ReplaceContentStep do
      argument :path, input(:path)
      where(&File.exists?(&1.path))
    end

    flunk :fail, "abort" do
      wait_for :read
    end

    return :read
  end

  setup context do
    test_sig =
      context
      |> Map.take(~w[line module file test]a)
      |> :erlang.phash2()
      |> Integer.to_string(16)

    base = System.tmp_dir!()

    tmp_dir = Path.join(base, test_sig)
    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "when the predicate is true, it runs the step", %{tmp_dir: tmp_dir} do
    test_file = Path.join(tmp_dir, "the_file.txt")
    File.write!(test_file, "Great Scott!")

    Reactor.run!(PredicateReactor, %{path: test_file})

    assert File.read!(test_file) != "Great Scott!"
  end

  test "when the predicate is not true, it bypasses the step", %{tmp_dir: tmp_dir} do
    test_file = Path.join(tmp_dir, "the_file.txt")
    assert {:ok, nil} = Reactor.run(PredicateReactor, %{path: test_file})

    refute File.exists?(test_file)
  end

  test "when a step is skipped it is not undone on failure", %{tmp_dir: tmp_dir} do
    test_file = Path.join(tmp_dir, "the_file.txt")

    assert {:error, error} = Reactor.run(FailingPredicateReactor, %{path: test_file})
    assert Exception.message(error) =~ "abort"
  end
end
