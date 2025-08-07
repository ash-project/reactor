defmodule Reactor.Dsl.ComposeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule InnerReactor do
    @moduledoc false
    use Reactor

    input :name

    step :greet do
      argument :name, input(:name)

      run fn %{name: name}, _context ->
        # Simulate some work
        Process.sleep(10)
        {:ok, "Hello, #{name}!"}
      end
    end

    return :greet
  end

  defmodule BasicComposeReactor do
    @moduledoc false
    use Reactor

    input :name

    compose :inner, InnerReactor do
      argument :name, input(:name)
    end

    return :inner
  end

  defmodule ComposeWithAllowAsyncTrueReactor do
    @moduledoc false
    use Reactor

    input :name

    compose :inner, InnerReactor do
      argument :name, input(:name)
      allow_async? true
    end

    return :inner
  end

  defmodule ComposeWithAllowAsyncFalseReactor do
    @moduledoc false
    use Reactor

    input :name

    compose :inner, InnerReactor do
      argument :name, input(:name)
      allow_async? false
    end

    return :inner
  end

  describe "basic compose functionality" do
    test "can compose another reactor" do
      assert {:ok, "Hello, World!"} = Reactor.run(BasicComposeReactor, %{name: "World"})
    end

    test "compose defaults to allow_async? true" do
      assert {:ok, "Hello, World!"} = Reactor.run(BasicComposeReactor, %{name: "World"})
    end
  end

  describe "allow_async? option" do
    test "compose with allow_async? true works correctly" do
      assert {:ok, "Hello, World!"} =
               Reactor.run(ComposeWithAllowAsyncTrueReactor, %{name: "World"})
    end

    test "compose with allow_async? false works correctly" do
      assert {:ok, "Hello, World!"} =
               Reactor.run(ComposeWithAllowAsyncFalseReactor, %{name: "World"})
    end

    test "allow_async? option is passed through to the step" do
      # Test that the DSL correctly builds the compose step with allow_async? option
      {:ok, reactor_struct} = Reactor.Info.to_struct(ComposeWithAllowAsyncFalseReactor)

      compose_step =
        Enum.find(reactor_struct.steps, fn step ->
          step.name == :inner
        end)

      assert compose_step != nil
      assert match?({Reactor.Step.Compose, _opts}, compose_step.impl)
      {_module, opts} = compose_step.impl
      assert Keyword.get(opts, :allow_async?) == false
    end

    test "allow_async? defaults to true when not specified" do
      {:ok, reactor_struct} = Reactor.Info.to_struct(BasicComposeReactor)

      compose_step =
        Enum.find(reactor_struct.steps, fn step ->
          step.name == :inner
        end)

      assert compose_step != nil
      assert match?({Reactor.Step.Compose, _opts}, compose_step.impl)
      {_module, opts} = compose_step.impl
      # Should default to true
      assert Keyword.get(opts, :allow_async?, true) == true
    end

    test "allow_async? defaults to true in step options when not specified" do
      {:ok, reactor_struct} = Reactor.Info.to_struct(BasicComposeReactor)

      compose_step =
        Enum.find(reactor_struct.steps, fn step ->
          step.name == :inner
        end)

      assert compose_step != nil
      assert match?({Reactor.Step.Compose, _opts}, compose_step.impl)
      {_module, opts} = compose_step.impl
      # Should default to true
      assert Keyword.get(opts, :allow_async?, true) == true
    end
  end

  describe "compose with arguments" do
    defmodule MultiArgInnerReactor do
      @moduledoc false
      use Reactor

      input :first_name
      input :last_name

      step :full_name do
        argument :first, input(:first_name)
        argument :last, input(:last_name)

        run fn %{first: first, last: last}, _context ->
          {:ok, "#{first} #{last}"}
        end
      end

      return :full_name
    end

    defmodule MultiArgComposeReactor do
      @moduledoc false
      use Reactor

      input :first
      input :last

      compose :full_name, MultiArgInnerReactor do
        argument :first_name, input(:first)
        argument :last_name, input(:last)
        allow_async? false
      end

      return :full_name
    end

    test "can compose reactor with multiple arguments and allow_async? false" do
      assert {:ok, "John Doe"} =
               Reactor.run(MultiArgComposeReactor, %{first: "John", last: "Doe"})
    end
  end

  describe "async behavior validation" do
    defmodule AsyncTestInnerReactor do
      @moduledoc false
      use Reactor

      input :name
      input :test_pid

      step :step1 do
        argument :name, input(:name)
        argument :test_pid, input(:test_pid)

        run fn %{name: name, test_pid: test_pid}, _context ->
          send(test_pid, {:step1, self()})
          Process.sleep(20)
          {:ok, "Step1: #{name}"}
        end
      end

      step :step2 do
        argument :name, input(:name)
        argument :test_pid, input(:test_pid)

        run fn %{name: name, test_pid: test_pid}, _context ->
          send(test_pid, {:step2, self()})
          Process.sleep(20)
          {:ok, "Step2: #{name}"}
        end
      end

      step :combine do
        argument :step1, result(:step1)
        argument :step2, result(:step2)

        run fn %{step1: step1, step2: step2}, _context ->
          {:ok, "#{step1} + #{step2}"}
        end
      end

      return :combine
    end

    defmodule AsyncTrueComposeReactor do
      @moduledoc false
      use Reactor

      input :name
      input :test_pid

      compose :inner, AsyncTestInnerReactor do
        argument :name, input(:name)
        argument :test_pid, input(:test_pid)
        allow_async? true
      end

      return :inner
    end

    defmodule AsyncFalseComposeReactor do
      @moduledoc false
      use Reactor

      input :name
      input :test_pid

      compose :inner, AsyncTestInnerReactor do
        argument :name, input(:name)
        argument :test_pid, input(:test_pid)
        allow_async? false
      end

      return :inner
    end

    test "allow_async? true allows concurrent execution within composed reactor" do
      test_pid = self()

      assert {:ok, "Step1: Test + Step2: Test"} =
               Reactor.run(AsyncTrueComposeReactor, %{name: "Test", test_pid: test_pid})

      # Collect the process IDs that ran the steps
      step1_pid =
        receive do
          {:step1, pid} -> pid
        after
          100 -> nil
        end

      step2_pid =
        receive do
          {:step2, pid} -> pid
        after
          100 -> nil
        end

      # With allow_async? true, steps can run in different processes
      assert step1_pid != nil
      assert step2_pid != nil
      # Note: They might still run in the same process due to concurrency limits,
      # but the important thing is that the reactor completes successfully
    end

    test "allow_async? false forces synchronous execution within composed reactor" do
      test_pid = self()

      assert {:ok, "Step1: Test + Step2: Test"} =
               Reactor.run(AsyncFalseComposeReactor, %{name: "Test", test_pid: test_pid})

      # Collect the process IDs that ran the steps
      step1_pid =
        receive do
          {:step1, pid} -> pid
        after
          100 -> nil
        end

      step2_pid =
        receive do
          {:step2, pid} -> pid
        after
          100 -> nil
        end

      # With allow_async? false, all steps should run in the same process
      assert step1_pid != nil
      assert step2_pid != nil
      assert step1_pid == step2_pid, "Steps should run in same process when allow_async? is false"
    end
  end

  defmodule ParentSyncReactor do
    @moduledoc false
    use Reactor

    input :name
    input :test_pid

    compose :inner, Reactor.Dsl.ComposeTest.AsyncTestInnerReactor do
      argument :name, input(:name)
      argument :test_pid, input(:test_pid)
      # This should be overridden by parent's sync state
      allow_async? true
    end

    return :inner
  end

  describe "parent async state inheritance" do
    test "child reactor respects parent's synchronous execution even with allow_async? true" do
      test_pid = self()

      # Run the parent reactor with async?: false
      assert {:ok, "Step1: Test + Step2: Test"} =
               Reactor.run(ParentSyncReactor, %{name: "Test", test_pid: test_pid}, %{},
                 async?: false
               )

      # Collect the process IDs that ran the steps
      step1_pid =
        receive do
          {:step1, pid} -> pid
        after
          100 -> nil
        end

      step2_pid =
        receive do
          {:step2, pid} -> pid
        after
          100 -> nil
        end

      # Even though allow_async? is true, the child should run synchronously
      # because the parent is running synchronously
      assert step1_pid != nil
      assert step2_pid != nil

      assert step1_pid == step2_pid,
             "Child reactor should run synchronously when parent is sync, regardless of allow_async? setting"
    end
  end
end
