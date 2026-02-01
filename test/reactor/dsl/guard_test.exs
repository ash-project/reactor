# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.GuardTest do
  use ExUnit.Case, async: true

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

  defmodule CachedReadReactor do
    @moduledoc false
    use Reactor

    input :path

    step :read do
      argument :path, input(:path)

      run fn args ->
        {:ok, File.read!(args.path)}
      end

      guard(fn args, context ->
        maybe_result =
          context
          |> Map.get(:cache, %{})
          |> Map.get(args.path)

        if maybe_result do
          {:halt, {:ok, maybe_result}}
        else
          :cont
        end
      end)
    end
  end

  test "when the guard halts the step isn't run and it's result is returned", %{tmp_dir: tmp_dir} do
    test_file = Path.join(tmp_dir, "the_file.txt")
    File.write!(test_file, "Great Scott!")

    assert {:ok, "This is heavy"} =
             Reactor.run(CachedReadReactor, %{path: test_file}, %{
               cache: %{test_file => "This is heavy"}
             })
  end

  test "when the guard continues, the step is run as normal", %{tmp_dir: tmp_dir} do
    test_file = Path.join(tmp_dir, "the_file.txt")
    File.write!(test_file, "Great Scott!")

    assert {:ok, "Great Scott!"} = Reactor.run(CachedReadReactor, %{path: test_file})
  end
end
