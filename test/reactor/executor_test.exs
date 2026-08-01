# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.ExecutorTest do
  @moduledoc false
  alias Reactor.{Builder, Executor.ConcurrencyTracker}
  use ExUnit.Case, async: true
  use Mimic
  import ExUnit.CaptureLog

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

  describe "halting while an asynchronous step is in flight" do
    defmodule AsyncHaltReactor do
      @moduledoc false
      use Reactor

      step :slow do
        run(fn _arguments, %{test_pid: test_pid, sleep: sleep} ->
          Process.sleep(sleep)
          send(test_pid, :slow_ran)
          {:ok, :slow}
        end)
      end

      step :halter do
        run(fn _arguments, _context -> {:halt, :waiting} end)
      end

      return(:slow)
    end

    test "the in-flight step is awaited and its result kept in the halted reactor" do
      assert {:halted, halted} =
               Reactor.run(AsyncHaltReactor, %{}, %{test_pid: self(), sleep: 300}, async?: true)

      assert_received :slow_ran
      assert halted.intermediate_results[:slow] == :slow
    end

    test "a step which completed while the reactor halted is not run again on resume" do
      assert {:halted, halted} =
               Reactor.run(AsyncHaltReactor, %{}, %{test_pid: self(), sleep: 300}, async?: true)

      assert_received :slow_ran

      assert {:ok, :slow} =
               Reactor.run(halted, %{}, %{test_pid: self(), sleep: 0},
                 async?: true,
                 max_iterations: 100
               )

      refute_received :slow_ran
    end

    test "no step is reported as abandoned when the in-flight step completes in time" do
      log =
        capture_log(fn ->
          assert {:halted, _halted} =
                   Reactor.run(AsyncHaltReactor, %{}, %{test_pid: self(), sleep: 300},
                     async?: true
                   )
        end)

      refute log =~ "will be abandoned"
    end

    defmodule DynamicStepHaltReactor do
      @moduledoc false
      use Reactor

      defmodule Producer do
        @moduledoc false
        use Reactor.Step

        @impl true
        def run(_arguments, context, _options) do
          Process.sleep(100)
          send(context.test_pid, :producer_ran)

          {:ok, step} =
            Reactor.Builder.new_step(
              :dynamic,
              {Reactor.Step.AnonFn, run: fn _arguments, _context -> {:ok, :dynamic} end}
            )

          {:ok, :produced, [step]}
        end
      end

      step(:producer, Producer)

      step :halter do
        run(fn _arguments, _context -> {:halt, :waiting} end)
      end

      return(:producer)
    end

    test "a step which produced new steps while the reactor halted is not run again on resume" do
      assert {:halted, halted} =
               Reactor.run(DynamicStepHaltReactor, %{}, %{test_pid: self()}, async?: true)

      assert_received :producer_ran

      assert {:ok, :produced} =
               Reactor.run(halted, %{}, %{test_pid: self()}, async?: true, max_iterations: 100)

      refute_received :producer_ran
    end

    defmodule RecursiveHaltReactor do
      @moduledoc false
      use Reactor

      defmodule CountDown do
        @moduledoc false
        use Reactor.Step

        @impl true
        def run(%{from: from}, context, _options) do
          Process.sleep(100)
          send(context.test_pid, {:counted, :initial})
          {:ok, [from], [next_step()]}
        end

        def run(%{numbers: [0 | _] = numbers}, _context, _options),
          do: {:ok, Enum.reverse(numbers)}

        def run(%{numbers: [number | _] = numbers}, context, _options) do
          send(context.test_pid, {:counted, number})
          {:ok, [number - 1 | numbers], [next_step()]}
        end

        defp next_step do
          {:ok, step} =
            Reactor.Builder.new_step(:count_down, __MODULE__, numbers: {:result, :count_down})

          step
        end
      end

      input(:from)

      step :count_down, CountDown do
        argument(:from, input(:from))
      end

      step :halter do
        run(fn _arguments, _context -> {:halt, :waiting} end)
      end

      return(:count_down)
    end

    test "a recursive step interrupted by a halt continues from where it left off on resume" do
      assert {:halted, halted} =
               Reactor.run(RecursiveHaltReactor, %{from: 3}, %{test_pid: self()}, async?: true)

      assert_received {:counted, :initial}

      assert {:ok, [3, 2, 1, 0]} =
               Reactor.run(halted, %{from: 3}, %{test_pid: self()},
                 async?: true,
                 max_iterations: 100
               )

      refute_received {:counted, :initial}
      assert_received {:counted, 3}
    end

    test "abandoning a step does not release its concurrency slot back to a shared pool" do
      concurrency_key = ConcurrencyTracker.allocate_pool(4)

      capture_log(fn ->
        assert {:halted, _halted} =
                 Reactor.run(AsyncHaltReactor, %{}, %{test_pid: self(), sleep: 500},
                   async?: true,
                   halt_timeout: 10,
                   concurrency_key: concurrency_key
                 )
      end)

      assert {:ok, 3, 4} = ConcurrencyTracker.status(concurrency_key)
    end

    test "an abandoned step's concurrency slot returns to a shared pool when the step eventually finishes" do
      concurrency_key = ConcurrencyTracker.allocate_pool(4)

      capture_log(fn ->
        assert {:halted, _halted} =
                 Reactor.run(AsyncHaltReactor, %{}, %{test_pid: self(), sleep: 200},
                   async?: true,
                   halt_timeout: 10,
                   concurrency_key: concurrency_key
                 )
      end)

      assert_receive :slow_ran, 1_000
      assert {:ok, 4, 4} = await_status(concurrency_key, {:ok, 4, 4})
    end

    test "a reactor which abandoned an in-flight step can be resumed" do
      capture_log(fn ->
        assert {:halted, halted} =
                 Reactor.run(AsyncHaltReactor, %{}, %{test_pid: self(), sleep: 500},
                   async?: true,
                   halt_timeout: 10
                 )

        refute_received :slow_ran

        assert {:ok, :slow} =
                 Reactor.run(halted, %{}, %{test_pid: self(), sleep: 0},
                   async?: true,
                   max_iterations: 100
                 )
      end)
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

    defp await_status(concurrency_key, expected) do
      Enum.reduce_while(1..100, ConcurrencyTracker.status(concurrency_key), fn _, _ ->
        case ConcurrencyTracker.status(concurrency_key) do
          ^expected ->
            {:halt, expected}

          other ->
            Process.sleep(10)
            {:cont, other}
        end
      end)
    end

    defp measure_elapsed(fun) do
      started_at = DateTime.utc_now()

      fun.()

      DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
    end
  end

  describe "reactor timeout" do
    defmodule SlowStepReactor do
      @moduledoc false
      use Reactor

      step :slow do
        run(fn _arguments, _context ->
          Process.sleep(300)
          {:ok, :slow}
        end)
      end

      return(:slow)
    end

    test "an in-flight step completing within the halt timeout is kept and not reported as abandoned" do
      log =
        capture_log(fn ->
          assert {:halted, halted} =
                   Reactor.run(SlowStepReactor, %{}, %{},
                     async?: true,
                     timeout: 100,
                     halt_timeout: 1_000
                   )

          assert halted.intermediate_results[:slow] == :slow
          assert {:ok, :slow} = Reactor.run(halted, %{}, %{}, async?: true)
        end)

      refute log =~ "will be abandoned"
    end

    test "when the timeout is elapsed, it halts the reactor" do
      elapsed =
        measure_elapsed(fn ->
          assert {:halted, reactor} =
                   Reactor.run(SleepyReactor, %{}, %{}, async?: false, timeout: 200)

          assert Multigraph.num_vertices(reactor.plan) == 3
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

    test "the executor does not spin while waiting for a retry backoff" do
      test_pid = self()

      Example.Step.Doable
      |> expect(:run, 2, fn
        _arguments, %{current_try: 0}, _options -> :retry
        _arguments, %{current_try: 1}, _options -> {:ok, :finished}
      end)
      |> expect(:backoff, fn _reason, _arguments, _context, _options ->
        send(test_pid, {:backoff_started, self()})

        receive do
          :start_backoff ->
            send(test_pid, :backoff_returning)
            500
        end
      end)

      task =
        Task.async(fn ->
          Reactor.run(RetryReactor, %{}, %{}, async?: false)
        end)

      assert_receive {:backoff_started, executor_pid}, 500
      assert executor_pid == task.pid

      send(executor_pid, :start_backoff)
      assert_receive :backoff_returning, 500

      Process.sleep(10)

      assert [status: :waiting, reductions: reductions_before] =
               Process.info(task.pid, [:status, :reductions])

      Process.sleep(50)

      assert [status: :waiting, reductions: reductions_after] =
               Process.info(task.pid, [:status, :reductions])

      assert {:ok, :finished} = Task.await(task, 1_000)

      # A suspended process should accrue almost no reductions. This generous ceiling
      # allows for the executor finishing its backoff setup after sending the signal.
      assert reductions_after - reductions_before < 100_000
    end

    test "waiting for a retry backoff does not exhaust the iteration limit" do
      Example.Step.Doable
      |> expect(:run, 2, fn
        _arguments, %{current_try: 0}, _options -> :retry
        _arguments, %{current_try: 1}, _options -> {:ok, :finished}
      end)
      |> expect(:backoff, fn _reason, _arguments, _context, _options -> 50 end)

      assert {:ok, :finished} =
               Reactor.run(RetryReactor, %{}, %{}, async?: false, max_iterations: 4)
    end

    test "the executor does not wait when the iteration limit cannot reach the retry" do
      Example.Step.Doable
      |> expect(:run, fn _arguments, %{current_try: 0}, _options -> :retry end)
      |> expect(:backoff, fn _reason, _arguments, _context, _options -> 1_000 end)

      task =
        Task.async(fn ->
          Reactor.run(RetryReactor, %{}, %{}, async?: false, max_iterations: 2)
        end)

      assert {:halted, _reactor} = Task.await(task, 250)
    end

    test "reactor timeout interrupts waiting for a retry backoff" do
      test_pid = self()

      Example.Step.Doable
      |> expect(:run, fn _arguments, %{current_try: 0}, _options -> :retry end)
      |> expect(:backoff, fn _reason, _arguments, _context, _options ->
        send(test_pid, :backoff_started)
        500
      end)

      task =
        Task.async(fn ->
          Reactor.run(RetryReactor, %{}, %{}, async?: false, timeout: 50)
        end)

      assert_receive :backoff_started, 500
      assert {:halted, _reactor} = Task.await(task, 250)
    end

    test "active async tasks prevent sleeping until a retry backoff expires" do
      test_pid = self()

      backoff_step =
        {Reactor.Step.AnonFn,
         run: fn _arguments, %{current_try: 0} ->
           :retry
         end,
         backoff: fn _reason, _arguments, _context ->
           send(test_pid, {:backoff_started, self()})

           receive do
             :start_backoff ->
               send(test_pid, :backoff_returning)
               1_000
           end
         end}

      halt_step =
        {Reactor.Step.AnonFn,
         run: fn _arguments, _context ->
           send(test_pid, {:halt_step_started, self()})

           receive do
             :finish -> {:halt, :finished}
           end
         end}

      reactor =
        Builder.new()
        |> Builder.add_step!(:backoff, backoff_step, [], max_retries: 1)
        |> Builder.add_step!(:halt, halt_step)
        |> Builder.return!(:backoff)

      task = Task.async(fn -> Reactor.run(reactor) end)

      assert_receive {:halt_step_started, halt_step_pid}, 500
      assert_receive {:backoff_started, backoff_step_pid}, 500

      send(backoff_step_pid, :start_backoff)
      assert_receive :backoff_returning, 500

      # Let the executor collect the backoff result and pass through another
      # async-task polling window before completing the remaining task.
      Process.sleep(250)

      send(halt_step_pid, :finish)

      assert {:halted, _reactor} = Task.await(task, 500)
    end

    test "the executor waits for the earliest retry backoff" do
      test_pid = self()

      step = fn name, delay ->
        {Reactor.Step.AnonFn,
         run: fn
           _arguments, %{current_try: 0} ->
             :retry

           _arguments, %{current_try: 1} ->
             send(test_pid, {:retried, name})
             {:ok, name}
         end,
         backoff: fn _reason, _arguments, _context -> delay end}
      end

      reactor =
        Builder.new()
        |> Builder.add_step!(:short, step.(:short, 100), [], max_retries: 1)
        |> Builder.add_step!(:long, step.(:long, 1_000), [], max_retries: 1)
        |> Builder.return!(:short)

      task =
        Task.async(fn ->
          Reactor.run(reactor, %{}, %{}, async?: false)
        end)

      assert_receive {:retried, :short}, 400
      refute_receive {:retried, :long}, 100
      assert {:ok, :short} = Task.await(task, 1_000)
    end
  end
end
