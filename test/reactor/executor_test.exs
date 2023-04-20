defmodule Reactor.ExecutorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "synchronous execution" do
    defmodule SyncReactor do
      @moduledoc false
      use Reactor

      input(:name)

      step :atom_to_string do
        argument :name, input(:name)

        impl(fn %{name: name}, _, _ ->
          {:ok, Atom.to_string(name)}
        end)

        async?(false)
      end

      step :upcase do
        argument :name, result(:atom_to_string)

        impl(fn %{name: name} = args, _, _ ->
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
        impl(fn _, _, _ ->
          {:ok, self()}
        end)
      end

      step :b do
        impl(fn _, _, _ ->
          {:ok, self()}
        end)
      end

      step :c do
        impl(fn _, _, _ ->
          {:ok, self()}
        end)
      end

      step :d do
        impl(fn _, _, _ ->
          {:ok, self()}
        end)
      end

      step :result do
        argument :a, result(:a)
        argument :b, result(:b)
        argument :c, result(:c)
        argument :d, result(:d)

        impl(fn args, _, _ ->
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

        impl(fn %{name: name}, _, _ ->
          {:halt, Atom.to_string(name)}
        end)
      end

      step :upcase do
        argument :name, result(:atom_to_string)

        impl(fn %{name: name}, _, _ ->
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

        def can?(:undo), do: true
        def can?(_), do: false

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

      assert {:error, ["I fail"]} =
               Reactor.Executor.run(reactor, %{agent: agent}, %{}, max_iterations: 100)

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

        def can?(_), do: false

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
end
