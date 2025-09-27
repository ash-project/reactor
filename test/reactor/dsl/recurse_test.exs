# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.RecurseTest do
  use ExUnit.Case, async: true

  defmodule FactorialReactor do
    use Reactor

    input :n
    input :acc

    step :calculate do
      argument :n, input(:n)
      argument :acc, input(:acc)

      run fn %{n: n, acc: acc}, _context ->
        {:ok, %{n: n - 1, acc: acc * n}}
      end
    end

    return :calculate
  end

  defmodule FibonacciReactor do
    use Reactor

    input :n
    input :a
    input :b

    step :calculate do
      argument :n, input(:n)
      argument :a, input(:a)
      argument :b, input(:b)

      run fn %{n: n, a: a, b: b}, _context ->
        {:ok, %{n: n - 1, a: b, b: a + b}}
      end
    end

    return :calculate
  end

  defmodule RecursiveReactor do
    use Reactor

    input :value

    recurse :factorial, FactorialReactor do
      argument :n, input(:value)
      argument :acc, value(1)
      max_iterations 10
      exit_condition fn %{n: n} -> n <= 1 end
    end

    recurse :fibonacci, FibonacciReactor do
      argument :n, input(:value)
      argument :a, value(0)
      argument :b, value(1)
      max_iterations 20
      exit_condition fn %{n: n} -> n <= 0 end
    end

    step :combine do
      argument :fact, result(:factorial)
      argument :fib, result(:fibonacci)

      run fn %{fact: fact, fib: fib}, _context ->
        {:ok, %{factorial: fact.acc, fibonacci: fib.b}}
      end
    end

    return :combine
  end

  test "recurse executes a reactor until exit condition is met" do
    result = Reactor.run!(RecursiveReactor, %{value: 5})

    # 5!
    assert result.factorial == 120
    # 6th Fibonacci number (0-indexed)
    assert result.fibonacci == 8
  end

  test "recurse stops at max_iterations if no exit condition is met" do
    defmodule InfiniteRecurseReactor do
      use Reactor

      input :counter

      step :increment do
        argument :counter, input(:counter)

        run fn %{counter: counter}, _context ->
          {:ok, %{counter: counter + 1}}
        end
      end

      return :increment
    end

    defmodule MaxIterationsReactor do
      use Reactor

      input :counter

      recurse :with_max, InfiniteRecurseReactor do
        argument :counter, input(:counter)
        max_iterations 5
      end

      return :with_max
    end

    result = Reactor.run!(MaxIterationsReactor, %{counter: 0})
    assert result.counter == 5
  end

  test "recurse with exit condition only" do
    defmodule ExitConditionReactor do
      use Reactor

      input :counter

      step :increment do
        argument :counter, input(:counter)

        run fn %{counter: counter}, _context ->
          {:ok, %{counter: counter + 1}}
        end
      end

      return :increment
    end

    defmodule ExitOnlyReactor do
      use Reactor

      input :counter

      recurse :until_ten, ExitConditionReactor do
        argument :counter, value(0)
        max_iterations 20
        exit_condition fn %{counter: counter} -> counter >= 10 end
      end

      return :until_ten
    end

    result = Reactor.run!(ExitOnlyReactor, %{counter: 0})
    assert result.counter == 10
  end

  test "recurse fails when neither max_iterations nor exit_condition is provided" do
    warning =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        defmodule InvalidRecurseReactor do
          use Reactor

          recurse :invalid, FactorialReactor do
            argument :n, value(5)
            argument :acc, value(1)
          end
        end
      end)

    assert warning =~ "Missing constraints for recursion"
  end
end
