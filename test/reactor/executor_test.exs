# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.ExecutorTest do
  @moduledoc false
  alias Reactor.Executor.ConcurrencyTracker
  use ExUnit.Case, async: true
  use Mimic

  describe "synchronous execution" do
    defmodule SyncReactor do
      @moduledoc false
      use Reactor

      input(:name)

      step :atom_to_string do
        argument :name, input(:name)

        run(fn %{name: name}, _ ->
          {:ok, Atom.to_string(name)}
        end)

        async?(false)
      end

      step :upcase do
        argument :name, result(:atom_to_string)

        run(fn %{name: name}, _ ->
          {:ok, String.upcase(name)}
        end)

        async?(false)
      end
    end

    test "it executes the steps" do
      {:ok, reactor} = Reactor.Info.to_struct(SyncReactor)
      {:ok, reactor} = Reactor.Planner.plan(reactor)

      assert {:ok, "MARTY"} =
               Reactor.Executor.run(reactor, %{name: :marty}, %{}, max_iterations: 100)
    end
  end

  describe "asynchronous execution" do
    defmodule AsyncReactor do
      @moduledoc false
      use Reactor

      step :a do
        run(fn _, _ ->
          {:ok, self()}
        end)
      end

      step :b do
        run(fn _, _ ->
          {:ok, self()}
        end)
      end

      step :c do
        run(fn _, _ ->
          {:ok, self()}
        end)
      end

      step :d do
        run(fn _, _ ->
          {:ok, self()}
        end)
      end

      step :result do
        argument :a, result(:a)
        argument :b, result(:b)
        argument :c, result(:c)
        argument :d, result(:d)

        run(fn args, _ ->
          {:ok, Map.values(args)}
        end)
      end

      return(:result)
    end

    test "the steps execute in separate pids" do
      {:ok, reactor} = Reactor.Info.to_struct(AsyncReactor)
      {:ok, reactor} = Reactor.Planner.plan(reactor)

      assert {:ok, pids} = Reactor.Executor.run(reactor, %{}, %{}, max_iterations: 100)

      refute self() in pids
      assert MapSet.size(MapSet.new(pids)) == 4
    end
  end

  describe "reactor halting" do
    defmodule HaltingReactor do
      @moduledoc false
      use Reactor

      input(:name)

      step :atom_to_string do
        argument :name, input(:name)

        run(fn %{name: name}, _ ->
          {:halt, Atom.to_string(name)}
        end)
      end

      step :upcase do
        argument :name, result(:atom_to_string)

        run(fn %{name: name}, _ ->
          {:ok, String.upcase(name)}
        end)
      end

      return(:upcase)
    end

    test "the reactor halts and can be resumed" do
      {:ok, reactor} = Reactor.Info.to_struct(HaltingReactor)
      {:ok, reactor} = Reactor.Planner.plan(reactor)

      assert {:halted, reactor} =
               Reactor.Executor.run(reactor, %{name: :marty}, %{}, max_iterations: 100)

      assert reactor.state == :halted

      assert {:ok, "MARTY"} =
               Reactor.Executor.run(reactor, %{name: :marty}, %{}, max_iterations: 100)
    end
  end

  describe "reactor undo" do
    defmodule UndoReactor do
      @moduledoc false
      use Reactor

      input(:agent)

      defmodule UndoableStep do
        @moduledoc false
        use Reactor.Step

        def run(%{agent: agent}, _, opts) do
          if Keyword.get(opts, :fail, false) do
            {:error, "I fail"}
          else
            Agent.update(agent, &MapSet.put(&1, Keyword.fetch!(opts, :name)))
            {:ok, "I succeed"}
          end
        end

        def undo(_, %{agent: agent}, _, opts) do
          Agent.update(agent, &MapSet.delete(&1, Keyword.fetch!(opts, :name)))
          :ok
        end
      end

      step :effect1, {UndoableStep, name: :effect1} do
        argument :agent, input(:agent)
      end

      step :effect2, {UndoableStep, name: :effect2} do
        argument :agent, input(:agent)
      end

      step :effect3, {UndoableStep, name: :effect3} do
        argument :agent, input(:agent)
      end

      step :effect4, {UndoableStep, name: :effect4, fail: true} do
        argument :agent, input(:agent)
      end
    end

    test "successful steps can be undone" do
      {:ok, reactor} = Reactor.Info.to_struct(UndoReactor)
      {:ok, reactor} = Reactor.Planner.plan(reactor)

      {:ok, agent} = Agent.start_link(fn -> MapSet.new() end)

      assert {:error, error} =
               Reactor.Executor.run(reactor, %{agent: agent}, %{}, max_iterations: 100)

      assert Exception.message(error) =~ "I fail"

      effects = Agent.get(agent, & &1)

      assert MapSet.size(effects) == 0
    end
  end

  describe "dynamic step appending" do
    defmodule TerribleIdeaReactor do
      @moduledoc false
      use Reactor

      defmodule CountDown do
        @moduledoc false
        use Reactor.Step

        def run(%{from: from}, _, _) do
          {:ok, step} =
            Reactor.Builder.new_step(:count_down, __MODULE__, numbers: {:result, :count_down})

          {:ok, [from], [step]}
        end

        def run(%{numbers: [0 | _] = numbers}, _, _), do: {:ok, Enum.reverse(numbers)}

        def run(%{numbers: [number | _] = numbers}, _, _) do
          {:ok, step} =
            Reactor.Builder.new_step(:count_down, __MODULE__, numbers: {:result, :count_down})

          {:ok, [number - 1 | numbers], [step]}
        end
      end

      input :from

      step :count_down, CountDown do
        argument :from, input(:from)
      end

      return :count_down
    end

    test "it executes dynamically added steps" do
      {:ok, reactor} = Reactor.Info.to_struct(TerribleIdeaReactor)
      {:ok, reactor} = Reactor.Planner.plan(reactor)

      assert {:ok, [7, 6, 5, 4, 3, 2, 1, 0]} =
               Reactor.Executor.run(reactor, %{from: 7}, %{}, max_iterations: 100)
    end
  end

  describe "argument transformation" do
    defmodule ArgumentTransformReactor do
      @moduledoc false
      use Reactor

      input :whom
      input :when

      step :blame do
        argument :whom, input(:whom) do
          transform &"#{&1.first_name} #{&1.last_name}"
        end

        argument :when, input(:when) do
          transform & &1.year
        end

        run(fn args, _ ->
          {:ok, "#{args.whom} in #{args.when}"}
        end)
      end

      return :blame
    end

    test "it correctly transforms the arguments" do
      assert {:ok, "Marty McFly in 1985"} =
               Reactor.run(ArgumentTransformReactor, %{
                 whom: %{first_name: "Marty", last_name: "McFly"},
                 when: ~N[1985-10-26 01:22:00]
               })
    end

    defmodule AllArgumentsTransformReactor do
      @moduledoc false
      use Reactor

      input :whom
      input :when

      step :blame do
        argument :whom, input(:whom)
        argument :when, input(:when)

        transform &%{whom: "#{&1.whom.first_name} #{&1.whom.last_name}", when: &1.when.year}

        run(fn args, _ ->
          {:ok, "#{args.whom} in #{args.when}"}
        end)
      end

      return :blame
    end

    test "it correctly transforms all the arguments" do
      assert {:ok, "Marty McFly in 1985"} =
               Reactor.run(AllArgumentsTransformReactor, %{
                 whom: %{first_name: "Marty", last_name: "McFly"},
                 when: ~N[1985-10-26 01:22:00]
               })
    end
  end

  defmodule SleepyReactor do
    @moduledoc false
    use Reactor

    step :a do
      run fn _, _ ->
        Process.sleep(100)
        {:ok, 1}
      end
    end

    step :b do
      run fn _, _ ->
        Process.sleep(100)
        {:ok, 2}
      end
    end

    step :c do
      run fn _, _ ->
        Process.sleep(100)
        {:ok, 3}
      end
    end

    step :d do
      run fn _, _ ->
        Process.sleep(100)
        {:ok, 4}
      end
    end

    step :e do
      run fn _, _ ->
        Process.sleep(100)
        {:ok, 5}
      end
    end
  end

  describe "async? option" do
    # Yes I know this is a dumb methodology, but what my theory presupposes is -
    # maybe it isn't?

    test "it can be run synchronously" do
      elapsed =
        measure_elapsed(fn ->
          assert {:ok, _} = Reactor.run(SleepyReactor, %{}, %{}, async?: false)
        end)

      assert elapsed >= 500
    end

    test "it can be run asynchronously" do
      elapsed =
        measure_elapsed(fn ->
          assert {:ok, _} = Reactor.run(SleepyReactor, %{}, %{}, async?: true)
        end)

      assert elapsed >= 100 and elapsed <= 500
    end

    defp measure_elapsed(fun) do
      started_at = DateTime.utc_now()

      fun.()

      DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
    end
  end

  describe "reactor timeout" do
    test "when the timeout is elapsed, it halts the reactor" do
      elapsed =
        measure_elapsed(fn ->
          assert {:halted, reactor} =
                   Reactor.run(SleepyReactor, %{}, %{}, async?: false, timeout: 200)

          assert Graph.num_vertices(reactor.plan) == 3
        end)

      assert elapsed <= 500
    end
  end

  describe "shared concurrency pools" do
    test "when multiple reactors share a concurrency pool, it limits the simultaneous number of processes" do
      defmodule ShortSleepReactor do
        @moduledoc false
        use Reactor

        step :a do
          run fn _ ->
            {:ok, Process.sleep(100)}
          end
        end
      end

      concurrency_key = ConcurrencyTracker.allocate_pool(1)

      assert {:ok, _} = Reactor.run(ShortSleepReactor, %{}, %{}, concurrency_key: concurrency_key)

      elapsed =
        :timer.tc(fn ->
          t0 =
            Task.async(fn ->
              {:ok, _} =
                Reactor.run(ShortSleepReactor, %{}, %{}, concurrency_key: concurrency_key)
            end)

          t1 =
            Task.async(fn ->
              {:ok, _} =
                Reactor.run(ShortSleepReactor, %{}, %{}, concurrency_key: concurrency_key)
            end)

          Task.await(t0)
          Task.await(t1)
        end)
        |> elem(0)
        |> System.convert_time_unit(:microsecond, :millisecond)

      assert elapsed >= 200
      assert elapsed < 300
    end

    test "reactors running inside async steps with shared concurrency don't cause a deadlock" do
      defmodule MaybeDeadlockedReactor.Inner do
        @moduledoc false
        use Reactor

        step :sleep do
          run(fn _ ->
            Process.sleep(100)
            {:ok, nil}
          end)
        end
      end

      defmodule MaybeDeadlockedReactor do
        @moduledoc false
        use Reactor

        for i <- 0..16 do
          step :"sleep_#{i}" do
            run(fn _, context ->
              Reactor.run(
                MaybeDeadlockedReactor.Inner,
                %{},
                %{},
                concurrency_key: context.concurrency_key
              )
            end)
          end
        end
      end

      Reactor.run(MaybeDeadlockedReactor, %{}, %{}, max_concurrency: 8)
    end

    test "lots of reactors sharing a concurrency key do not deadlock" do
      defmodule OversharingReactor do
        @moduledoc false
        use Reactor

        step :sleep do
          run fn _ ->
            Process.sleep(100)
            {:ok, nil}
          end
        end
      end

      pool = ConcurrencyTracker.allocate_pool(8)

      0..16
      |> Enum.map(fn _ ->
        Task.async(fn ->
          Reactor.run(OversharingReactor, %{}, %{}, concurrency_key: pool)
        end)
      end)
      |> Enum.map(&Task.await/1)
    end

    test "Zach's hunch" do
      defmodule GrandchildReactor do
        @moduledoc false
        use Reactor

        step :sleep do
          run fn _ ->
            Process.sleep(1000)
            {:ok, nil}
          end
        end
      end

      defmodule ChildReactor do
        @moduledoc false
        use Reactor

        step :splode do
          run fn _, context ->
            0..16
            |> Enum.map(fn _ ->
              Task.async(fn ->
                Reactor.run(GrandchildReactor, %{}, %{}, concurrency_key: context.concurrency_key)
              end)
            end)
            |> Enum.map(&Task.await/1)

            {:ok, nil}
          end
        end
      end

      defmodule ParentReactor do
        @moduledoc false
        use Reactor

        step :splode do
          run fn _ ->
            pool = ConcurrencyTracker.allocate_pool(16)

            0..16
            |> Enum.map(fn _ ->
              Task.async(fn -> Reactor.run(ChildReactor, %{}, %{}, concurrency_key: pool) end)
            end)
            |> Enum.map(&Task.await/1)

            {:ok, nil}
          end
        end
      end
    end

    Reactor.run(ParentReactor)
  end

  describe "retry backoff" do
    defmodule RetryReactor do
      use Reactor

      step :that_retry_lifestyle, Example.Step.Doable, max_retries: 10
    end

    test "steps can provide their own retry backoff" do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> :retry end)
      |> expect(:backoff, 10, fn _, _, _, _ -> 10 end)

      start_time = System.monotonic_time(:millisecond)

      Reactor.run(RetryReactor, %{}, async?: false)

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      assert elapsed >= 100
    end

    test "steps without a backoff retry quickly" do
      Example.Step.Doable
      |> stub(:run, fn _, _, _ -> :retry end)

      start_time = System.monotonic_time(:millisecond)

      Reactor.run(RetryReactor, %{}, async?: false)

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      assert elapsed < 100
    end
  end
end
