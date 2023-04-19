# Reactor

# Initial discussion notes

- Ash.Engine has `actor`/`authorize?` built in
  - in `Reactor` this should be replaced with something potentially like "context" or "globals"
- Don't need to support "run the chain in a transaction", that would be done by passing a specific 
- Potentially provide some kind of protocol for taking chain context and putting it onto errors, 
  that `def_ash_exception` can implement automatically?
- provide a custom template handler so that `Ash.Flow` can enable `expr` to be used i.e `branch expr(is_nil(result(:get_organization)))`
  or it should just take a function probably? It should definitely take a function, but is that 
- this needs to be made streaming friendly, unlike Ash.Engine
- this includes streaming out results
- Stream native?
- Requests (a.k.a Link.t()) do not have a lifecycle. They just have a single field to be resolved.
- Requests have a unique path that can be any elixir term
- Requests should have a configurable `async?` option.
- use libgraph or something to handle the dependency management?

```elixir
defmacro expr(expression) do
  quote
    fn expression, context -> 
      Expr.eval(expression, context)
    end
  end
end

# Returns a streamable, but internally tracks state in a way that it supports more operations
# like splitting a stream
defmodule StreamingChain do
  input :users

  return :do_for_each_user

  map :do_for_each_user, input(:users) do
    ..
    split &predicate/1 do
      ...
    end
  end
end

defmodule CreateUserAndOrg do
  use Reactor.Chain

  input :username
  input :password
  input :organization_name
  #input :foo do
  #  cast_input &cast_input/1
  #end

  def compensate(failure) do

  end

  link :get_organization, GetOrganization do
    argument :organization_name, input(:organization_name)
  end

  branch :get_or_create_organization do
    condition :check_if_organization_created, &(&1.organization) do
      argument :organization, result(:organization)
    end

    argument :organization, result(:get_organization)
    condition &(not is_nil(&1.organization))
    
    on_true do
      output result(:create_organization)
      link :create_organization, CreateOrganization do
        argument :organization_name, input(:organization_name)
      end
    end

    on_false do
      output result(:get_organization)
    end
  end

  composite_link :transaction, Transaction do

  end

  link :create_user, CreateUser do
    argument :username, input(:username) # {:chain_input, :username}
    argument :password, input(:password) # {:chain_input, :password}
    argument :organization, result(:get_or_create_organization) # {:chain_result, :get_or_create_organization}
  end
end
```

```elixir
defmodule GetOrganization do
  use Reactor.Link

  def run(arguments, context) do
    {:ok, %Organization{}} | {:error, term()}
  end

  def compensate(result, arguments, context) do
    # ?
  end
end

transaction :transaction do
  context %{in_transaction?: true}

  link Link
  # and in that link
  def compensate(result, arguments, context) do
    if context[:in_transaction?] do
      
    else
      
    end
  end
end

# map/reduce should be native, not implemented as a composite link
# defmodule Map do
#  def run(arguments, context, links) do
#    arguments[:elements]
#    |> Stream.map()
#  end
# end

defmodule Transaction do
  use Reactor.CompositeLink

  @spec run(map(), context :: map(), [Reactor.Link.t()]) :: compensation_result()
  def run(arguments, context, links) do
    Repo.transaction(fn -> 
      {:ok, Reactor.run(links, Map.put(context, :in_transaction?, true))}
    end)
    |> case do
    {:ok, _} ->
      {:ok, [], context}
    {:error, error} ->
      {:error, error}
    end
    # if this wasn't a transaction, you could just return the links/modify them
    # i.e {:ok, links, context}
  end

  @spec compensate([Reactor.Link.t()], arguments, context) :: compensation_result()
  def compensate(links, arguments, context) do
    # Reactor.Link.compensate(links)
  end
end
```