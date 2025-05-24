# Rules for working with Reactor

## Understanding Reactor

Reactor is a dynamic, concurrent, dependency resolving saga orchestrator for Elixir. It provides:

- **Saga orchestration** - Transaction-like semantics across multiple distinct resources with rollback capabilities
- **Dependency resolution** - Automatic calculation of execution order based on step dependencies using a directed acyclic graph (DAG)
- **Concurrent execution** - Runs as many steps as possible concurrently while respecting dependencies
- **Dynamic workflows** - Build workflows at runtime and add steps while the reactor is running
- **Composable DSL** - Declarative approach to defining workflows

Read documentation *before* attempting to use Reactor features. Do not assume prior knowledge of the framework or its conventions.

## Core Concepts

### Reactors
A Reactor is a workflow definition that contains inputs, steps, and their dependencies. Reactors can be defined using the DSL or built programmatically.

### Steps
Steps are the unit of work in a Reactor. Each step:
- Has a unique name
- Can depend on inputs or results from other steps
- Can run synchronously or asynchronously
- Can be compensated (handle errors) or undone (rollback on failure)
- Returns a result that other steps can use

### Arguments
Arguments define dependencies between steps. They specify:
- What data a step needs
- Where that data comes from (inputs or other step results)
- Optional transformations to apply to the data

## Code Structure & Organization

- Define Reactors as modules using the DSL for static workflows
- Use `Reactor.Builder` for dynamic workflow construction
- Create custom steps by implementing the `Reactor.Step` behaviour
- Organize complex workflows into composable sub-reactors
- Use meaningful names for inputs, steps, and arguments

## Basic Reactor DSL

Define a Reactor using the DSL:

```elixir
defmodule MyApp.UserRegistrationReactor do
  use Reactor

  # Define inputs (like function arguments)
  input :email
  input :password
  input :plan_name

  # Define steps with dependencies
  step :validate_email do
    argument :email, input(:email)
    run fn %{email: email}, _ ->
      if String.contains?(email, "@") do
        {:ok, email}
      else
        {:error, "Invalid email"}
      end
    end
  end

  step :hash_password do
    argument :password, input(:password)
    run fn %{password: password}, _ ->
      {:ok, Bcrypt.hash_pwd_salt(password)}
    end
  end

  step :create_user, MyApp.Steps.CreateUser do
    argument :email, result(:validate_email)
    argument :password_hash, result(:hash_password)
  end

  # Specify what to return
  return :create_user
end
```

## Step Implementation

### Using Anonymous Functions

For simple steps, use anonymous functions directly in the DSL:

```elixir
step :transform_data do
  argument :input, input(:raw_data)

  run fn %{input: data}, _ ->
    {:ok, String.upcase(data)}
  end
end
```

### Using Step Modules

For complex logic, implement the `Reactor.Step` behaviour:

```elixir
defmodule MyApp.Steps.CreateUser do
  use Reactor.Step

  @impl true
  def run(arguments, context, options) do
    case create_user(arguments.email, arguments.password_hash) do
      {:ok, user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def compensate(reason, arguments, context, options) do
    # Handle errors - decide whether to retry or continue with rollback
    case reason do
      %DBConnection.ConnectionError{} -> :retry
      _other -> :ok
    end
  end

  @impl true
  def undo(user, arguments, context, options) do
    # Rollback successful execution
    case delete_user(user) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_user(email, password_hash) do
    # Implementation here
  end

  defp delete_user(user) do
    # Implementation here
  end
end
```

## Step Return Values

Steps can return various values to control reactor execution:

- `{:ok, value}` - Success with result value
- `{:ok, value, [step]}` - Success with additional steps to add
- `{:error, reason}` - Failure (triggers compensation/undo)
- `:retry` or `{:retry, reason}` - Retry the step
- `{:halt, reason}` - Pause reactor execution

## Arguments and Dependencies

### Basic Arguments

```elixir
step :example do
  # Use input directly
  argument :email, input(:email)

  # Use result from another step
  argument :user, result(:create_user)

  # Use a static value
  argument :timeout, value(5000)
end
```

### Argument Transformations

Transform argument values before passing to steps:

```elixir
step :example do
  # Transform with anonymous function
  argument :user_id do
    source result(:create_user)
    transform &(&1.id)
  end

  # Extract nested values
  argument :birth_year, input(:user_data, [:birth_date, :year])

  # Transform input
  argument :age do
    source input(:birth_year)
    transform fn year -> Date.utc_today().year - year end
  end
end
```

## Built-in Step Types

### Debug Steps

Log information during execution:

```elixir
debug :log_user do
  argument :user, result(:create_user)
  argument :message, value("User created successfully")
end
```

### Map Steps

Process collections by applying steps to each element:

```elixir
map :process_users do
  source input(:user_list)
  batch_size 10
  allow_async? true

  step :validate_user do
    argument :user, element(:process_users)
    run fn %{user: user}, _ ->
      validate_user(user)
    end
  end
end
```

### Compose Steps

Embed one reactor inside another:

```elixir
compose :sub_workflow, MyApp.SubReactor do
  argument :input_data, result(:prepare_data)
end
```

### Switch Steps

Conditional execution based on predicates:

```elixir
switch :handle_user_type do
  on result(:user)

  matches? &(&1.type == :premium) do
    step :setup_premium_features do
      argument :user, result(:user)
      # Premium setup logic
    end
  end

  default do
    step :setup_basic_features do
      argument :user, result(:user)
      # Basic setup logic
    end
  end
end
```

### Group Steps

Execute related steps together with shared setup/teardown:

```elixir
group :user_setup do
  before_all &MyApp.setup_database/3
  after_all &MyApp.cleanup_database/1

  step :create_profile do
    # Profile creation logic
  end

  step :send_welcome_email do
    # Email logic
  end
end
```

### Around Steps

Wrap step execution with custom logic:

```elixir
around :transaction, &MyApp.with_transaction/4 do
  step :create_user do
    # User creation in transaction
  end

  step :create_profile do
    # Profile creation in transaction
  end
end
```

### Collect Steps

Gather multiple values into a single structure:

```elixir
collect :user_summary do
  argument :user, result(:create_user)
  argument :profile, result(:create_profile)
  argument :settings, result(:create_settings)

  transform fn inputs ->
    %{
      user: inputs.user,
      profile: inputs.profile,
      settings: inputs.settings
    }
  end
end
```

### Template Steps

Dynamically create steps based on runtime data:

```elixir
template :dynamic_processors do
  argument :processor_configs, input(:configs)

  # Creates steps based on the processor_configs at runtime
end
```

## Error Handling and Compensation

### Compensation
Handle step failures and decide how to proceed:

```elixir
defmodule MyApp.Steps.ApiCall do
  use Reactor.Step

  def run(arguments, context, options) do
    case make_api_call(arguments.url) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def compensate(reason, arguments, context, options) do
    case reason do
      # Retry on network errors
      %HTTPoison.Error{reason: :timeout} -> :retry
      %HTTPoison.Error{reason: :econnrefused} -> :retry

      # Continue with error for other failures
      _other -> :ok
    end
  end
end
```

### Undo Operations
Rollback successful operations when later steps fail:

```elixir
defmodule MyApp.Steps.CreateResource do
  use Reactor.Step

  def run(arguments, context, options) do
    {:ok, create_resource(arguments)}
  end

  def undo(resource, arguments, context, options) do
    case delete_resource(resource) do
      :ok -> :ok
      {:error, :not_found} -> :ok  # Already deleted
      {:error, reason} -> {:error, reason}
    end
  end
end
```

## Async vs Sync Execution

### Async Steps (Default)
Steps run asynchronously by default:

```elixir
step :async_operation do
  # Runs asynchronously
  run fn _, _ -> {:ok, "result"} end
end
```

### Sync Steps
Force synchronous execution:

```elixir
step :sync_operation do
  async? false
  run fn _, _ -> {:ok, "result"} end
end
```

### Conditional Async
Make async behavior conditional:

```elixir
step :conditional_async do
  async? fn options -> options[:force_sync] != true end
  run fn _, _ -> {:ok, "result"} end
end
```

## Running Reactors

### Basic Execution

```elixir
# Run with inputs
{:ok, result} = Reactor.run(MyApp.UserRegistrationReactor,
  email: "user@example.com",
  password: "secret123",
  plan_name: "premium"
)

# Run with options
{:ok, result} = Reactor.run(reactor, inputs, context,
  async?: false,
  max_concurrency: 10
)
```

### Halting and Resuming

```elixir
# Step returns {:halt, reason}
{:halted, reactor_state} = Reactor.run(MyReactor, inputs)

# Resume later
{:ok, result} = Reactor.run(reactor_state, %{}, %{})
```

## Middleware

Add cross-cutting concerns with middleware:

```elixir
defmodule MyApp.LoggingMiddleware do
  use Reactor.Middleware

  def init(context) do
    Logger.info("Reactor starting")
    {:ok, context}
  end

  def complete(result, context) do
    Logger.info("Reactor completed successfully")
    {:ok, result}
  end

  def error(errors, context) do
    Logger.error("Reactor failed: #{inspect(errors)}")
    :ok
  end

  def event({:run_start, args}, step, context) do
    Logger.debug("Step #{step.name} starting with #{inspect(args)}")
  end

  def event({:run_complete, result}, step, context) do
    Logger.debug("Step #{step.name} completed with #{inspect(result)}")
  end
end

# Add to reactor
defmodule MyApp.ReactorWithMiddleware do
  use Reactor

  middlewares do
    middleware MyApp.LoggingMiddleware
    middleware Reactor.Middleware.Telemetry
  end

  # Steps...
end
```

## Guards and Conditions

Control step execution with guards:

```elixir
step :conditional_step do
  argument :user, result(:create_user)

  # Only run if guard passes
  guard &(&1.user.active?)

  run fn %{user: user}, _ ->
    {:ok, "Processing active user: #{user.name}"}
  end
end
```

Use where clauses for complex conditions:

```elixir
step :premium_feature do
  argument :user, result(:create_user)

  where fn %{user: user} ->
    user.plan == :premium and user.active?
  end

  run fn %{user: user}, _ ->
    enable_premium_features(user)
  end
end
```

## Wait For Dependencies

Explicit dependencies without data flow:

```elixir
step :send_notification do
  argument :user, result(:create_user)

  # Wait for email verification to complete
  wait_for :verify_email

  run fn %{user: user}, _ ->
    send_welcome_notification(user)
  end
end
```

## Best Practices

### Error Handling
- Implement `compensate/4` for retryable errors
- Implement `undo/4` for operations that need rollback
- Use specific error types to guide compensation logic
- Log errors appropriately for debugging
- If available, do work transactionally if possible
- If building an Ash application, use `Ash.Reactor` steps

### Performance
- Use `async? false` sparingly - only when order matters
- Set appropriate `batch_size` for map operations
- Use `strict_ordering? false` in map steps when order doesn't matter
- Consider `max_concurrency` limits for resource-constrained operations

### Code Organization
- Create reusable step modules for common operations
- Use compose steps to break complex workflows into smaller reactors
- Group related steps with shared setup/teardown
- Use meaningful names for all components

### Testing
- Test steps in isolation using the step module directly
- Test reactors with various input combinations
- Test error scenarios and compensation logic
- Use `async? false` in tests for deterministic execution

### Debugging
- Use debug steps to log intermediate values
- Add telemetry middleware for observability
- Use descriptive names and descriptions for steps
- Test with `async? false` to simplify debugging

## Advanced Features

### Context Usage
Pass data through the reactor context:

```elixir
# In a step
def run(arguments, context, options) do
  user = context[:current_user]
  # Use context data
end

# Run with context
Reactor.run(reactor, inputs, %{current_user: user})
```

### Transform Functions
Apply transformations to inputs and arguments:

```elixir
input :birth_date do
  transform &Date.from_iso8601!/1
end

step :calculate_age do
  argument :birth_date do
    source input(:birth_date)
    transform fn date -> Date.diff(Date.utc_today(), date) end
  end
end
```

### Retries and Limits
Control retry behavior:

```elixir
step :api_call do
  max_retries 3

  run fn args, _ ->
    # May fail and retry up to 3 times
  end

  compensate fn reason, _, _, _ ->
    case reason do
      %HTTPError{status: 503} -> :retry
      _ -> :ok
    end
  end
end
```

### Reactor Composition
Build larger workflows from smaller ones:

```elixir
defmodule MyApp.MainWorkflow do
  use Reactor

  input :user_data

  # Run sub-workflow
  compose :user_setup, MyApp.UserSetupReactor do
    argument :data, input(:user_data)
  end

  # Continue with more steps
  step :finalize do
    argument :setup_result, result(:user_setup)
    # Finalization logic
  end
end
```
