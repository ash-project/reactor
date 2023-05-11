# Getting started with Reactor

Reactor is a lot of things:

- A [saga orchestrator](https://www.cs.cornell.edu/andru/cs711/2002fa/reading/sagas.pdf).
- A [composable DSL](https://ash-hq.org/docs/dsl/reactor) for creating workflows.
- A [builder](https://ash-hq.org/module/reactor/latest/reactor-builder) for dynamically creating workflows.
- Capable of mixing concurrent and serialised workflows.
- Resolves dependencies between tasks using a [directed acyclic graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph).

Let's start by breaking down what each of these features are, and how we can use them.

## Transaction-like semantics with Sagas

If you've been building apps long enough you will have used database transactions. They're amazing. Basically, if you put all your changes in a transaction and there's a failure then the transaction gets rolled back and the system is not left in an inconsistent state. This is great when you're working with a single database, but in the modern world we often have to integrate with [many](https://www.postgresql.org/) [different](https://www.mongodb.com/) [kinds](https://redis.io/) [of](https://cassandra.apache.org/_/index.html) [data](https://aws.amazon.com/redshift/) [stores](https://clickhouse.com/) and [as](https://www.salesforce.com/) [many](https://stripe.com/) [different](https://www.twilio.com/en-us) [SaaS](https://www.xero.com/) [products](https://www.vendhq.com/).

Often we need to orchestrate a "transaction" across multiple services at once; for example:

1. Register a new user
2. Create a Stripe customer
3. Create a Stripe subscription
4. Send a transactional welcome email via SendGrid
5. Track the conversion in Salesforce

If any of these steps fails we may want to retry or roll back depending on what failed and whether it's recoverable. Reactor allows us to do this by defining the `Reactor.Step` behaviour:

```elixir
defmodule MyApp.CreateStripeSubscriptionStep do
  use Reactor.Step

  @impl true
  def run(arguments, context, options) do
    Stripe.Subscription.create(arguments.stripe_customer_id, items: [plan: arguments.stripe_plan_id])
  end

  @impl true
  def compensate(%{code: :network_error}, arguments, context, options) do
    :retry
  end

  def compensate(error, arguments, context, options) do
    :ok
  end

  @impl true
  def undo(subscription, arguments, context, options) do
    case Stripe.Subscription.delete(subscription) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

Here we've defined a step that tries to create a new Stripe subscription. If that fails then we have defined `compensate/4` check whether it was a network error, and if so ask the Reactor to retry, otherwise we return `:ok` because the subscription wasn't created so we don't have to do any other clean up. Lastly, we define `undo/4` to delete the subscription if the Reactor asks us to undo our work - which it will do if a step later in the workflow fails.

How do you compose these steps together you ask? Let's discuss that in the next section.

## Composing steps with the Reactor DSL

Reactor uses [`spark`](https://ash-hq.org/docs/guides/spark/latest/tutorials/get-started-with-spark) to define an easy to use (and easy to extend) DSL for defining workflows. Let's start with an example:

```elixir
defmodule MyApp.RegisterUserReactor do
  use Reactor

  input :email
  input :password
  input :plan_name

  step :register_user, MyApp.RegisterUserStep do
    argument :email, input(:email)
    argument :password, input(:password)
  end

  step :create_stripe_customer, MyApp.CreateStripeCustomerStep do
    argument :email, input(:email)
  end

  step :find_stripe_plan, MyApp.FindStripePlanStep do
    argument :plan_name, input(:plan_name)
  end

  step :create_stripe_subscription, MyApp.CreateStripeSubscriptionStep do
    argument :customer_id do
      source result(:create_stripe_customer)
      transform &(&1.id)
    end

    argument :plan_id do
      source result(:get_stripe_plan)
      transform &(&1.id)
    end
  end

  step :send_welcome_email, MyApp.SendWelcomeEmailStep do
    argument :email, input(:email)
    argument :_subscription, result(:create_stripe_subscription)
  end

  step :track_conversion, MyApp.TrackSalesforceConversionStep do
    argument :email, input(:email)
    argument :plan_name, input(:plan_name)
    argument :_welcome_email, result(:send_welcome_email)
  end

  return :register_user
end
```

Here we've defined a Reactor that performs the steps needed for the user registration example above.

Here we define the steps that need to be performed and describe the dependencies between them by way of arguments.

> #### Beware of ordering {: .warning}
>
> Whilst the order of the steps in the example makes sense logically it has no
> effect on the order that the Reactor will execute them in. This is the
> fundamental difference between Reactor and other Saga tools in the Elixir
> ecosystem.

The Reactor will put the steps into a graph with the steps as vertices and the arguments as edges and will find any that have no inbound edges and run as many of them at once as possible. This means that `:register_user`, `:create_stripe_customer` and `:find_stripe_plan` will all execute simultaneously, after which `:create_stripe_subscription`, then `:send_welcome_email` and `:track_conversion` will run. Notice that `:send_welcome_email` and `:track_conversion` have arguments that depend on the results of previews steps that they don't necessarily need, however we want to ensure that they don't run until all the important steps are complete (it's hard to unsend an email!)

## Building workflows programmatically

While using the DSL makes it extremely easy to build a static workflow, sometimes you need the flexibility to build a workflow based on a set of criteria that may not be known at compile time (for example if you're using user input to build the workflow).

Every Reactor is ultimately an instance of the `Reactor` struct (you can use `Reactor.Info.to_struct(MyApp.RegisterUserReactor)` to see the one for the DSL Reactor above). The functions in `Reactor.Builder` can be used to create an identical workflow:

    iex> reactor = Reactor.Builder.new()
    ...> {:ok, reactor} = Reactor.Builder.add_input(reactor, :email)
    ...> {:ok, reactor} = Reactor.Builder.add_input(reactor, :password)
    ...> {:ok, reactor} = Reactor.Builder.add_input(reactor, :plan_name)
    ...> {:ok, reactor} = Reactor.Builder.add_step(reactor, :register_user, MyApp.RegisterUserStep, email: {:input, :email}, password: {:input, :password})
    # etc...

## Mixing concurrent and synchronous workflow steps

If you look at the `Reactor.Step` struct, you'll see that it has an `async?` field. This is available as a step DSL option, and as an option to `add_step/5`. It defaults to `true`, however if you set it to `false` Reactor will run the step synchronously. Note that it will only run synchronous steps when it has run out of async steps which can be started. Other than that caveat, Reactor will follow the same ordering rules as specified above.

## Running your Reactor

You can pass either a Reactor DSL module or a Reactor struct straight into the `Reactor.run/1..4` function.

## Halting and resuming workflows

Any step in the flow can return `{:halt, value}` instead of `{:ok, value}`. When this happens Reactor will wait for any running asynchronous steps to finish and then halt the Reactor returning `{:halted, reactor}`. Later on you can resume the Reactor by passing the halted reactor to the `Reactor.run/1..4` function.

## Dynamically adding steps at Reactor run time

Any step can return `{:ok, value, additional_steps}` instead of just `{:ok, value}` and those new steps will be added to the graph and have their dependencies calculated automatically. `additional_steps` should be a list of `Reactor.Step` structs, which you can create with `Reactor.Builder.new_step/2..4`.

There are a couple of additional things to be aware of when steps at run time:

1. If you add steps that induce a cyclic dependency then the Reactor will commence an undo, just as if a step had failed.
2. Steps can have the same name as other steps and their intermediate results will be replaced.
3. You are allowed to make dependency cycles in the very specific case of a new
   step relying on it's own output.
