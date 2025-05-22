# Recursive Execution in Reactor

Recursion is a powerful pattern in programming, allowing an operation to be applied repeatedly until a condition is met. Reactor provides a dedicated DSL for recursive execution, which enables you to:

1. Execute a reactor iteratively
2. Pass results from one iteration as inputs to the next
3. Control termination with exit conditions or maximum iterations
4. Build complex iterative algorithms with ease

## Getting Started with Recursion

The basic structure of the `recurse` DSL element is:

```elixir
recurse :name, ReactorModule do
  # Arguments to the first iteration
  argument :arg1, input(:some_input)
  
  # Termination conditions (at least one is required)
  max_iterations: 10  # Optional: Maximum number of iterations
  exit_condition: fn result -> some_condition?(result) end  # Optional: Function that returns true when recursion should stop
end
```

## How Recursion Works

1. The first iteration runs using the provided arguments
2. The result of each iteration becomes the input to the next
3. After each iteration, the exit condition is checked (if provided)
4. If no exit condition is true and max iterations is not reached, the next iteration begins
5. When recursion completes, the result of the final iteration is returned

## Example: Calculating Factorial

Here's a simple example that calculates the factorial of a number using recursion:

```elixir
defmodule FactorialReactor do
  use Reactor

  input :n
  input :acc, default: 1

  step :calculate do
    argument :n, input(:n)
    argument :acc, input(:acc)

    run fn %{n: n, acc: acc}, _context ->
      {:ok, %{n: n - 1, acc: acc * n}}
    end
  end

  return :calculate
end

defmodule MainReactor do
  use Reactor

  input :number

  recurse :factorial, FactorialReactor do
    argument :n, input(:number)
    
    # Exit when n reaches 1 (factorial calculation complete)
    exit_condition: fn %{n: n} -> n <= 1 end
    
    # Safeguard against infinite recursion
    max_iterations: 100
  end

  return :factorial
end

# Usage:
Reactor.run!(MainReactor, %{number: 5})  # Returns %{n: 0, acc: 120}
```

## Termination Conditions

You must provide at least one termination condition to prevent infinite recursion:

### Exit Condition

A function that takes the result of an iteration and returns a boolean. When it returns `true`, recursion stops:

```elixir
recurse :converge, IterateReactor do
  # Stop when the delta between iterations is very small
  exit_condition: fn %{delta: delta} -> abs(delta) < 0.0001 end
end
```

### Maximum Iterations

An integer specifying the maximum number of iterations, regardless of other conditions:

```elixir
recurse :approximate, ApproximationReactor do
  # Run at most 100 iterations
  max_iterations: 100
end
```

## Advanced Example: Fixed-Point Algorithm

This example implements a fixed-point algorithm that iteratively refines a solution until it converges:

```elixir
defmodule NewtonMethod do
  use Reactor

  input :x  # Current approximation
  input :f  # Function to find root of
  input :f_prime  # Derivative of f
  
  step :refine do
    argument :x, input(:x)
    argument :f, input(:f)
    argument :f_prime, input(:f_prime)
    
    run fn %{x: x, f: f, f_prime: f_prime}, _context ->
      f_x = f.(x)
      f_prime_x = f_prime.(x)
      
      next_x = x - f_x / f_prime_x
      delta = next_x - x
      
      {:ok, %{
        x: next_x,
        f: f,
        f_prime: f_prime,
        delta: delta
      }}
    end
  end
  
  return :refine
end

defmodule SolveEquation do
  use Reactor
  
  input :initial_guess
  input :equation
  input :derivative
  
  recurse :solve, NewtonMethod do
    argument :x, input(:initial_guess)
    argument :f, input(:equation)
    argument :f_prime, input(:derivative)
    
    # Converge when change between iterations is very small
    exit_condition: fn %{delta: delta} -> abs(delta) < 0.0000001 end
    
    # Safety limit
    max_iterations: 50
  end
  
  step :extract_result do
    argument :solution, result(:solve)
    
    run fn %{solution: %{x: x}}, _context ->
      {:ok, x}
    end
  end
  
  return :extract_result
end

# Find the square root of 2 using Newton's method
f = fn x -> x*x - 2 end
f_prime = fn x -> 2*x end

result = Reactor.run!(SolveEquation, %{
  initial_guess: 1.0,
  equation: f,
  derivative: f_prime
})

# result is approximately 1.4142135623730951 (sqrt(2))
```

## Tips for Effective Recursion

1. **Always provide termination conditions**: Use both `exit_condition` and `max_iterations` when possible to prevent infinite loops.

2. **Design compatible inputs/outputs**: The output structure of your reactor must contain the same keys that it expects as input for the next iteration.

3. **Use minimal state**: Only carry forward the information needed for the next iteration to keep memory usage low.

4. **Consider performance**: For very large numbers of iterations, be mindful of memory usage as the recursion mechanism needs to track each iteration.

5. **Debug with `max_iterations`**: When developing, set a low `max_iterations` value to test without risk of infinite loops.

## Conclusion

The `recurse` DSL provides a powerful way to express iterative algorithms in a declarative manner. By separating the core logic of each iteration from the recursion mechanics, Reactor lets you focus on the algorithm itself while handling the iteration loop for you.