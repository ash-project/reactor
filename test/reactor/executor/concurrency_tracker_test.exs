# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Executor.ConcurrencyTrackerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Executor.ConcurrencyTracker

  describe "allocate_pool/1" do
    test "it returns a new pool key" do
      assert pool = allocate_pool(16)
      assert is_reference(pool)
    end

    test "it monitors the requesting process and destroys the pool when it exits" do
      pool =
        fn ->
          pool = allocate_pool(16)
          assert {:ok, _, _} = status(pool)
          pool
        end
        |> Task.async()
        |> Task.await()

      # We have to wait for the concurrency tracker to process the request.
      Process.sleep(10)

      assert {:error, _} = status(pool)
    end
  end

  describe "acquire/1" do
    test "when there is available concurrency in the pool, it returns ok" do
      pool = allocate_pool(16)
      assert {:ok, 1} = acquire(pool)
      assert {:ok, 15, 16} = status(pool)
    end

    test "when there is no available concurrency in the pool, it returns zero" do
      pool = allocate_pool(0)
      assert {:ok, 0} = acquire(pool)
    end

    test "when there is 1 slot left, it can be acquired" do
      pool = allocate_pool(1)
      assert {:ok, 1} = acquire(pool)
      assert {:ok, 0, 1} = status(pool)
    end
  end

  describe "release/1" do
    test "it increments the available concurrency in the pool when possible" do
      pool = allocate_pool(16)
      {:ok, 1} = acquire(pool)
      assert {:ok, 15, 16} = status(pool)
      assert :ok = release(pool)
      assert {:ok, 16, 16} = status(pool)
    end

    test "it doesn't allow the pool to grow" do
      pool = allocate_pool(16)
      assert {:ok, 16, 16} = status(pool)
      assert :error = release(pool)
      assert {:ok, 16, 16} = status(pool)
    end
  end
end
