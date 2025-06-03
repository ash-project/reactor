# How to Optimize Reactor Performance

## Problem
You need to improve the performance of your reactor workflows, optimize concurrency, handle large-scale processing efficiently, and scale your system to handle high throughput with minimal resource usage.

## Solution Overview
This guide covers systematic performance optimization techniques for Reactor workflows, including concurrency tuning, resource management, memory optimization, and monitoring strategies. You'll learn to identify bottlenecks and apply targeted optimizations.

## Prerequisites
- Understanding of Reactor basics (inputs, steps, arguments)
- Familiarity with Elixir concurrency concepts (processes, tasks, supervisors)
- Experience with async workflows and map steps
- Basic knowledge of system performance concepts

## Understanding Performance Characteristics

### Reactor's Performance Model

Reactor is designed for high-throughput, concurrent execution with these characteristics:

**Strengths:**
- **Automatic parallelisation**: Independent steps run concurrently by default
- **Resource pooling**: Shared concurrency pools across reactor instances
- **Lazy evaluation**: Only processes what's needed when it's needed
- **Efficient batching**: Map steps process collections in configurable chunks

**Bottlenecks to watch for:**
- **Dependency chains**: Sequential dependencies limit parallelisation
- **Resource contention**: Too many concurrent operations overwhelming external systems
- **Memory usage**: Large intermediate results consuming memory
- **CPU vs I/O mixing**: Synchronous CPU work blocking async I/O operations

## Concurrency Optimization

### 1. Configuring Basic Concurrency Limits

Control how many steps can run concurrently within a single reactor:

```elixir
defmodule DataProcessor do
  use Reactor

  input :user_ids

  # Multiple independent steps that can run in parallel
  step :fetch_profiles do
    argument :user_ids, input(:user_ids)
    run fn %{user_ids: ids}, _context ->
      profiles = fetch_user_profiles(ids)
      {:ok, profiles}
    end
  end

  step :fetch_preferences do
    argument :user_ids, input(:user_ids)
    run fn %{user_ids: ids}, _context ->
      preferences = fetch_user_preferences(ids)
      {:ok, preferences}
    end
  end

  step :fetch_activity do
    argument :user_ids, input(:user_ids)
    run fn %{user_ids: ids}, _context ->
      activity = fetch_user_activity(ids)
      {:ok, activity}
    end
  end

  # This step waits for all the above to complete
  step :combine_data do
    argument :profiles, result(:fetch_profiles)
    argument :preferences, result(:fetch_preferences)
    argument :activity, result(:fetch_activity)
    
    run fn args, _context ->
      combined = combine_user_data(args)
      {:ok, combined}
    end
  end

  return :combine_data
end

# Control concurrency when running the reactor
{:ok, result} = Reactor.run(
  DataProcessor,
  %{user_ids: [1, 2, 3, 4, 5]},
  %{},
  max_concurrency: 10  # At most 10 steps running concurrently
)
```

### 2. Tuning Concurrency Settings

Optimal concurrency settings depend on your specific workload and system characteristics. Start with these guidelines, then experiment and measure:

```elixir
# Starting points for different workload types:

# For I/O-bound workloads (API calls, database queries)
max_concurrency: System.schedulers_online() * 4  # 4x CPU cores

# For CPU-bound workloads  
max_concurrency: System.schedulers_online()      # 1x CPU cores

# For mixed workloads
max_concurrency: System.schedulers_online() * 2  # 2x CPU cores

# For external service limits (rate limiting)
max_concurrency: 10  # Based on service constraints
```

**How to find your optimal settings:**

1. **Start with the suggested baseline** for your workload type
2. **Monitor system resources** - CPU usage, memory, network connections
3. **Test with different values** - try 50%, 150%, 200% of your baseline
4. **Measure end-to-end performance** - both throughput and latency
5. **Watch for external bottlenecks** - database connection limits, API rate limits
6. **Consider system stability** - avoid settings that cause resource exhaustion

**Signs you need to adjust:**

- **Too low**: CPU cores are idle, external services aren't being fully utilised
- **Too high**: High memory usage, connection pool exhaustion, degraded response times
- **External limits**: Rate limiting errors, connection timeouts, service overload responses

### 3. Shared Concurrency Pools

Share concurrency pools across reactor instances to prevent resource competition:

```elixir
# Create a shared pool
{:ok, pool_key} = Reactor.Executor.ConcurrencyTracker.allocate_pool(100)

# Use the pool across multiple reactor runs
opts = [concurrency_key: pool_key, max_concurrency: 100]

# All these reactors share the same 100-task limit
Task.async(fn -> Reactor.run(DataProcessor, inputs1, %{}, opts) end)
Task.async(fn -> Reactor.run(DataProcessor, inputs2, %{}, opts) end) 
Task.async(fn -> Reactor.run(DataProcessor, inputs3, %{}, opts) end)
```

## Map Step Performance Optimization

### 1. Batch Size Tuning

Configure batch sizes based on data characteristics and system capacity:

```elixir
defmodule BatchProcessingReactor do
  use Reactor

  input :records
  input :processing_type

  # For small, fast operations - larger batches
  map :process_lightweight_data do
    argument :source, input(:records)
    batch_size 1000  # Process 1000 items at once
    allow_async? true
    
    step :validate do
      argument :record, element(:source)
      run fn %{record: record}, _context ->
        # Fast validation logic
        {:ok, validate_record(record)}
      end
    end
    
    return :validate
  end

  # For expensive operations - smaller batches  
  map :process_heavy_computation do
    argument :source, input(:records)
    batch_size 10    # Process only 10 items at once
    # Tune reactor-level max_concurrency for CPU-bound work
    
    step :complex_calculation do
      argument :record, element(:source)
      run fn %{record: record}, _context ->
        # CPU-intensive processing
        {:ok, expensive_computation(record)}
      end
    end
    
    return :complex_calculation
  end

  return template("Processing complete: {{ processed }} records") do
    assign :processed, result(:process_lightweight_data)
  end
end
```

### 2. Understanding Map Step Memory Usage

**Critical memory considerations** when using map steps:

Map steps have complex memory usage patterns that are a function of both **batch size** and **mapped result size**. Understanding this is crucial for processing large datasets efficiently.

#### Memory Usage Components

**1. Input Record Storage:**
Each batch of input records is converted into individual steps and added to the reactor state. These steps contain the input record as a `value` argument, contributing directly to memory usage until the step runs.

**2. Intermediate Results Storage:**
A new map step is emitted which depends on the results of all batch steps. This means **all batch step results are stored in Reactor's intermediate results** until the map step completes.

**3. Final Result Storage:**
The overall result of the map step (collection of all batch results) is likely to be depended upon by other steps, so remains in intermediate results storage.

#### Memory Usage Formula

```elixir
Total Memory ≈ (Batch Size × Input Record Size) + 
               (Batch Size × Output Result Size) + 
               (Final Collection Size)
```

#### Batch Size Guidelines by Data Characteristics

```elixir
# For small input records, small output results
batch_size 1000  # Safe - total memory stays manageable

# For large input records OR large output results  
batch_size 10    # Conservative - limits memory multiplication

# For very large transformations (e.g., image processing)
batch_size 1     # Process one at a time to avoid memory spikes

# Consider your total dataset size:
# 1M records × 100 batch size = 100K steps in memory at once
# 1M records × 10 batch size = 100K steps total, 10K at once
```

#### Example: Memory-Aware Batch Configuration

```elixir
# For small records and lightweight transformations
defmodule LightweightProcessor do
  use Reactor

  input :records

  map :process_records do
    source input(:records)
    batch_size 1000  # Safe for small records (~1KB each)
    
    step :transform_record do
      argument :record, element(:process_records)
      run fn %{record: record}, _context ->
        # Lightweight transformation
        {:ok, simple_transform(record)}
      end
    end
    
    return :transform_record
  end

  return :process_records
end

# For large records or heavy transformations  
defmodule HeavyProcessor do
  use Reactor

  input :records

  map :process_records do
    source input(:records)
    batch_size 10   # Conservative for large records (>10KB each)
    
    step :transform_record do
      argument :record, element(:process_records)
      run fn %{record: record}, _context ->
        # Heavy transformation that produces large results
        {:ok, complex_transform(record)}
      end
    end
    
    return :transform_record
  end

  return :process_records
end

# For very large records (images, files, etc.)
defmodule SingleItemProcessor do
  use Reactor

  input :large_items

  map :process_items do
    source input(:large_items)
    batch_size 1    # Process one large item at a time
    
    step :transform_item do
      argument :item, element(:process_items)
      run fn %{item: item}, _context ->
        # Memory-intensive processing (e.g., image manipulation)
        {:ok, process_large_item(item)}
      end
    end
    
    return :transform_item
  end

  return :process_items
end
```

### 3. Memory-Efficient Streaming

Process large datasets without loading everything into memory:

```elixir
defmodule StreamingProcessor do
  use Reactor

  input :file_path
  input :output_path

  # Stream file processing without loading entire file
  map :process_file_stream do
    argument :source, input(:file_path)
    batch_size 100
    strict_ordering? false  # Improves performance when order doesn't matter
    
    step :transform_line do
      argument :line, element(:source)
      run fn %{line: line}, _context ->
        transformed = transform_data(line)
        {:ok, transformed}
      end
    end
    
    return :transform_line
  end

  # Write results in batches  
  step :write_output do
    argument :processed_data, result(:process_file_stream)
    argument :output_path, input(:output_path)
    
    run fn %{processed_data: data, output_path: path}, _context ->
      File.stream!(path, [], :line)
      |> Stream.chunk_every(1000)
      |> Stream.each(&write_batch(&1))
      |> Stream.run()
      
      {:ok, :written}
    end
  end

  return :write_output
end

```

## CPU vs I/O Optimization

### 1. Optimizing CPU and I/O Operations

Balance concurrency based on operation type - I/O operations can handle high concurrency, while CPU operations should use more conservative limits:

```elixir
defmodule OptimalWorkloadReactor do
  use Reactor

  input :user_ids

  # I/O operations - keep async (default)
  step :fetch_profiles do
    argument :user_ids, input(:user_ids)
    run fn %{user_ids: ids}, _context ->
      profiles = fetch_user_profiles(ids)
      {:ok, profiles}
    end
  end

  step :fetch_preferences do  
    argument :user_ids, input(:user_ids)
    run fn %{user_ids: ids}, _context ->
      preferences = fetch_user_preferences(ids)
      {:ok, preferences}
    end
  end

  # CPU operations - keep async but use lower concurrency limits
  step :calculate_recommendations do
    argument :profiles, result(:fetch_profiles)
    argument :preferences, result(:fetch_preferences)
    
    run fn %{profiles: profiles, preferences: prefs}, _context ->
      recommendations = calculate_complex_recommendations(profiles, prefs)
      {:ok, recommendations}
    end
  end

  # I/O operation - back to async
  step :save_recommendations do
    argument :recommendations, result(:calculate_recommendations)
    run fn %{recommendations: recs}, _context ->
      save_to_database(recs)
      {:ok, :saved}
    end
  end

  return :save_recommendations
end

# Run with different concurrency settings based on workload
# For this mixed I/O + CPU reactor, use moderate concurrency
{:ok, result} = Reactor.run(
  OptimalWorkloadReactor,
  %{user_ids: [1, 2, 3, 4, 5]},
  %{},
  max_concurrency: System.schedulers_online() * 2  # Balanced for mixed workload
)
```

### 2. CPU-bound Map Operations

Handle CPU-intensive map operations efficiently:

```elixir
defmodule CPUIntensiveProcessor do
  use Reactor

  input :datasets

  # CPU-bound processing with controlled concurrency
  map :process_datasets do
    argument :source, input(:datasets)
    batch_size 5        # Small batches for CPU work
    # Tune reactor-level max_concurrency for CPU-bound work
    
    step :complex_analysis do
      argument :dataset, element(:source)
      run fn %{dataset: data}, _context ->
        # CPU-intensive mathematical analysis
        result = perform_statistical_analysis(data)
        {:ok, result}
      end
    end
    
    return :complex_analysis
  end

  return :process_datasets
end
```

## Memory Management

### 1. Controlling Intermediate Results

Minimize memory usage by avoiding unnecessary intermediate result storage. Remember that undoable steps will have their results stored in the reactor's undo stack, so non-undoable steps save memory:

```elixir
defmodule MemoryEfficientReactor do
  use Reactor

  input :large_dataset

  # This step's result won't be stored since no other steps depend on it
  # Also, it's not undoable so won't be kept in the undo stack
  step :validate_data do
    argument :data, input(:large_dataset)
    run fn %{data: data}, _context ->
      # Large intermediate result that we don't want to keep
      validated = validate_large_dataset(data) 
      
      # Return only what's needed for next steps
      summary = %{
        total_records: length(validated),
        valid_records: count_valid(validated),
        errors: extract_errors(validated)
      }
      
      {:ok, summary}
    end
    # No undo/4 callback defined = not undoable = no result stored in undo stack
  end

  # Use summary instead of full dataset
  step :generate_report do
    argument :summary, result(:validate_data)
    run fn %{summary: summary}, _context ->
      report = create_summary_report(summary)
      {:ok, report}
    end
  end

  return :generate_report
end
```


## Performance Monitoring

### 1. Adding Telemetry for Performance Tracking

Monitor reactor performance with built-in telemetry:

```elixir
defmodule MonitoredReactor do
  use Reactor
  
  middleware Reactor.Middleware.Telemetry

  input :data

  step :slow_operation do
    argument :data, input(:data)
    run fn %{data: data}, _context ->
      # Slow operation that we want to monitor
      result = expensive_operation(data)
      {:ok, result}
    end
  end

  return :slow_operation
end

# Set up telemetry handlers
:telemetry.attach_many(
  "reactor-performance",
  [
    [:reactor, :run, :start],
    [:reactor, :run, :stop],
    [:reactor, :step, :run, :start], 
    [:reactor, :step, :run, :stop]
  ],
  fn event, measurements, metadata, _config ->
    case event do
      [:reactor, :run, :stop] ->
        duration_ms = measurements.duration |> System.convert_time_unit(:native, :millisecond)
        Logger.info("Reactor completed in #{duration_ms}ms")
        
      [:reactor, :step, :run, :stop] ->
        duration_ms = measurements.duration |> System.convert_time_unit(:native, :millisecond)
        step_name = metadata.step.name
        Logger.debug("Step #{step_name} completed in #{duration_ms}ms")
        
      _ -> :ok
    end
  end,
  nil
)
```


## Performance Benchmarking

### 1. Using Benchee for Reactor Performance Testing

Use [Benchee](https://hex.pm/packages/benchee) to create professional performance benchmarks with detailed reports:

```elixir
# Add to mix.exs dependencies
{:benchee, "~> 1.0", only: :dev}

defmodule ReactorBenchmarks do
  def run_concurrency_benchmark do
    data = generate_test_data(1_000)
    
    Benchee.run(
      %{
        "concurrency_1" => fn ->
          Reactor.run(ProcessingReactor, %{data: data}, %{}, max_concurrency: 1)
        end,
        "concurrency_5" => fn ->
          Reactor.run(ProcessingReactor, %{data: data}, %{}, max_concurrency: 5)
        end,
        "concurrency_10" => fn ->
          Reactor.run(ProcessingReactor, %{data: data}, %{}, max_concurrency: 10)
        end,
        "concurrency_20" => fn ->
          Reactor.run(ProcessingReactor, %{data: data}, %{}, max_concurrency: 20)
        end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/concurrency_results.html"}
      ]
    )
  end

  def run_batch_size_benchmark do
    data = generate_test_data(1_000)
    
    # Use inputs to test different batch sizes
    Benchee.run(
      %{
        "map_processing" => fn {batch_size, data} ->
          reactor = create_map_reactor(batch_size)
          Reactor.run(reactor, %{data: data})
        end
      },
      inputs: %{
        "batch_10" => {10, data},
        "batch_50" => {50, data}, 
        "batch_100" => {100, data},
        "batch_500" => {500, data}
      },
      warmup: 1,
      time: 3,
      memory_time: 1
    )
  end

  def run_reactor_comparison_benchmark do
    data = generate_test_data(500)
    
    Benchee.run(
      %{
        "sync_reactor" => fn ->
          Reactor.run(SyncReactor, %{data: data}, %{}, async?: false)
        end,
        "async_reactor" => fn ->
          Reactor.run(AsyncReactor, %{data: data}, %{}, max_concurrency: 10)
        end,
        "optimized_reactor" => fn ->
          Reactor.run(OptimizedReactor, %{data: data}, %{}, max_concurrency: 5)
        end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/reactor_comparison.html"},
        {Benchee.Formatters.JSON, file: "benchmarks/reactor_comparison.json"}
      ]
    )
  end
end

# Example output from Benchee:
#
# Name                    ips        average  deviation         median         99th %
# concurrency_10      12.34 K       81.05 μs    ±15.23%       76.00 μs      145.67 μs
# concurrency_5        8.91 K      112.23 μs    ±18.45%      108.00 μs      189.34 μs
# concurrency_1        3.45 K      289.78 μs    ±12.67%      285.00 μs      387.23 μs
#
# Comparison:
# concurrency_10      12.34 K
# concurrency_5        8.91 K - 1.38x slower +31.18 μs
# concurrency_1        3.45 K - 3.58x slower +208.73 μs
```


## Common Performance Anti-patterns

### 1. Avoid: Blocking Async Steps

When a step blocks, identify the root cause and model dependencies properly:

```elixir
# ❌ BAD: Blocking because of missing dependency
step :process_data do
  run fn args, _context ->
    # Blocking while waiting for external resource
    wait_for_resource_to_be_ready()  # This wastes concurrency slots
    process_with_resource(args)
  end
end

# ✅ GOOD: Model the dependency explicitly with separate steps
step :prepare_resource do
  run fn _args, _context ->
    # This step ensures the resource is ready
    setup_resource()
    {:ok, :resource_ready}
  end
end

step :process_data do
  argument :resource_ready, result(:prepare_resource)
  argument :data, input(:data)
  run fn %{data: data}, _context ->
    # No blocking - resource dependency ensures it's ready
    process_with_resource(data)
  end
end

# ✅ BETTER: Use recursive step for external resources
step :wait_for_external_service do
  run fn args, context ->
    case check_external_service() do
      {:ok, result} -> 
        {:ok, result}
      {:error, :not_ready} ->
        # Emit the current step again - Reactor will retry when it can
        current_step = context.current_step
        {:ok, nil, [current_step]}
    end
  end
end
```

### 2. Avoid: Excessive Dependencies

Design workflows to maximise parallelisation:

```elixir
# ❌ BAD: Artificial sequential dependencies
step :step1, do: run(fn -> {:ok, data1} end)
step :step2 do
  argument :data1, result(:step1)  # Unnecessary dependency
  run fn %{data1: _} -> {:ok, data2} end  # Doesn't actually use data1
end
step :step3 do
  argument :data2, result(:step2)  # Creates sequential chain
  run fn %{data2: _} -> {:ok, data3} end
end

# ✅ GOOD: Independent steps run in parallel
step :step1, do: run(fn -> {:ok, data1} end)
step :step2, do: run(fn -> {:ok, data2} end)  # No dependency on step1
step :step3, do: run(fn -> {:ok, data3} end)  # No dependency on step2

# Combine results only when needed
step :combine_results do
  argument :data1, result(:step1)
  argument :data2, result(:step2)
  argument :data3, result(:step3)
  run fn args -> {:ok, combine(args)} end
end
```

## Performance Troubleshooting

### Common issues and solutions

**Problem**: Reactor runs slower than expected  
**Diagnosis**: Check for:
- Reactor concurrency limits that don't match your workload
- Overly conservative concurrency limits
- Sequential dependencies that prevent parallelisation

**Problem**: High memory usage  
**Diagnosis**: Check for:
- Large intermediate results being stored unnecessarily
- Map steps with batch sizes that are too large
- Streams not being processed lazily

**Problem**: External service rate limiting errors  
**Solution**: Use compensation with exponential backoff and reduce `max_concurrency`:

```elixir
step :api_call do
  run fn args, _context ->
    call_external_api(args)
  end
  
  compensate fn _args, context ->
    # Use current_try for exponential backoff
    retry_count = context.current_try
    delay_ms = :math.pow(2, retry_count) * 1000 |> round()
    
    Process.sleep(delay_ms)
    :retry
  end
end

# Also reduce concurrency to respect service limits
{:ok, result} = Reactor.run(
  APIReactor,
  inputs,
  %{},
  max_concurrency: 5  # Lower concurrency for rate-limited APIs
)
```

**Problem**: Inconsistent performance  
**Solution**: Ensure proper resource isolation and monitoring:

```elixir
# Use dedicated concurrency pools for different workload types
fast_pool = Reactor.Executor.ConcurrencyTracker.allocate_pool(100)
slow_pool = Reactor.Executor.ConcurrencyTracker.allocate_pool(10)

# Fast operations
Reactor.run(FastReactor, data, %{}, concurrency_key: fast_pool)

# Slow operations  
Reactor.run(SlowReactor, data, %{}, concurrency_key: slow_pool)
```

## Summary

Optimizing Reactor performance requires understanding your workload characteristics and applying appropriate strategies:

**For I/O-bound workloads:**
- Use higher concurrency limits (4x CPU cores)
- Keep steps async by default
- Use shared concurrency pools to prevent resource competition

**For CPU-bound workloads:**
- Tune reactor concurrency limits to match CPU cores
- Keep steps async but control resource usage via reactor max_concurrency
- Use smaller batch sizes in map operations

**For mixed workloads:**
- Separate I/O and CPU operations
- Use moderate concurrency limits (2x CPU cores)
- Monitor performance with telemetry

**For memory efficiency:**
- Process data in streams when possible
- Avoid storing large intermediate results
- Use appropriate batch sizes for your data characteristics

## Related Guides

- [Building Async Workflows](../tutorials/03-async-workflows.md) - Understanding Reactor's concurrency model
- [Data Processing Pipelines](data-pipelines.md) - Efficient batch processing patterns
- [Testing Strategies](testing-strategies.md) - Performance testing approaches
- [Debugging Workflows](debugging-workflows.md) - Performance monitoring and profiling