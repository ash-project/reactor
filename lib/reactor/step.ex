defmodule Reactor.Step do
  @moduledoc """
  The Step behaviour and struct.

  Implement this behaviour to make steps for your Reactor.
  """

  defstruct arguments: [], async?: true, impl: nil, name: nil, max_retries: :infinite, ref: nil

  alias Reactor.{Argument, Step}

  @type t :: %Step{
          arguments: [Argument.t()],
          async?: boolean,
          impl: module | {module, keyword},
          name: any,
          max_retries: non_neg_integer() | :infinity,
          ref: nil | reference()
        }

  @typedoc """
  Optional capabilities which may be implemented by the step module.

  This allows us to optimise out calls steps which cannot be undone, etc.
  """
  @type capability :: :compensate | :undo

  @typedoc """
  Possible valid return values for the `c:run/3` callback.
  """
  @type run_result ::
          {:ok, value :: any}
          | {:ok, value :: any, [Step.t()]}
          | {:halt | :error, reason :: any}

  @typedoc """
  Possible valid return values for the `c:compensate/4` callback.
  """
  @type compensate_result :: {:continue, value :: any} | :ok | :retry

  @typedoc """
  Possible valid return values for the `c:undo/4` callback.
  """
  @type undo_result :: :ok | :retry | {:error, any}

  @doc """
  Execute the step.

  This is the function that implements the behaviour you wish to execute.  You
  will receive arguments as per the `t:Step.t` definition along with their
  corresponding values as a map and a copy of the current reactor context.

  ## Arguments

    - `arguments` - A map of arguments as per the `t:Step.t` definition we're
      called from.
    - `context` - The reactor context.
    - `options` - A keyword list of options provided to the step (if any).

  ## Return values

    - `{:ok, value}` the step completed successfully it returns the value in an
      ok tuple.
    - `{:ok, value, [step]}` the step completed successfully and wants to add
      new steps to the reactor.
    - `{:error, reason}` the if step failed, return an error tuple.
    - `{:halt, reason}` terminate (or pause) reactor execution.  If there are
      actively running steps the reactor will wait for them to finish and then
      return the incomplete state for later resumption.
  """
  @callback run(
              arguments :: Reactor.inputs(),
              context :: Reactor.context(),
              options :: keyword
            ) :: run_result

  @doc """
  Compensate for the failure of the step.

  > Do not implement this callback if your step doesn't support compensation.

  If `run/3` returned an error then this callback will be called the error
  reason and the original arguments.

  This provides you the opportunity to handle the error in a number of ways and
  direct the reactor as to what to do next.

  This callback is only called if `c:can?/1` returns `true` for the
  `:compensate` capability.

  ## Arguments
    - `reason` - the error reason returned from `c:run/3`.
    - `arguments` - the arguments passed to the step.
    - `context` - the reactor context.
    - `options` - a keyword list of options provided to the step (if any).

  ## Return values

    - `{:continue, value}` if you're able to provide a valid result for the step
      (perhaps by re-running the original computation) then return that within a
      `:continue` tuple and execution will continue as planned.
    - `:ok` the step was successfully compensated and the reactor should
      continue undoing upstream changes.
    - `:retry` if you would like the reactor to attempt to re-run the step.
  """
  @callback compensate(
              reason :: any,
              arguments :: Reactor.inputs(),
              context :: Reactor.context(),
              options :: keyword
            ) :: compensate_result

  @doc """
  Undo a previously successful execution of the step.

  > Do not implement this callback if your step doesn't support undoing.

  This callback is called when the reactor encounters an unhandled error later
  in it's execution run and must undo the work previously done.

  This callback is only called if `c:can?/1` returns `true` for the `:undo`
  capability.

  ## Arguments

    - `value` - the return value of the previously successful call to `c:run/3`.
    - `arguments` - the arguments passed to the step.
    - `context` - the reactor context.
    - `options` - a keyword list of options provided to the step (if any).

  ## Return values

    - `:ok` the step was successfully undo and the reactor should continue
      rolling back.
    - `{:error, reason}` there was an error while attempting to compensate.  The
      reactor will collect the error and continue rolling back.
    - `:retry` if you would like the reactor to attempt to undo the again later
      - possibly in the case of a network failure for example.
  """
  @callback undo(
              value :: any,
              arguments :: Reactor.inputs(),
              Reactor.context(),
              options :: keyword
            ) :: undo_result

  @optional_callbacks compensate: 4, undo: 4

  @doc """
  Find out of a step has a capability.
  """
  @spec can?(module | Step.t(), capability()) :: boolean
  def can?(%Step{impl: {module, _opts}}, capability)
      when is_atom(module) and capability in ~w[undo compensate]a,
      do: function_exported?(module, capability, 4)

  def can?(%Step{impl: module}, capability)
      when is_atom(module) and capability in ~w[undo compensate]a,
      do: function_exported?(module, capability, 4)

  def can?(module, capability) when is_atom(module) and capability in ~w[undo compensate]a,
    do: function_exported?(module, capability, 4)

  def can?(_step, _capability), do: false

  @doc """
  Execute a step.
  """
  @spec run(Step.t(), arguments :: Reactor.inputs(), context :: Reactor.context()) :: run_result()
  def run(%{impl: {module, options}}, arguments, context) when is_atom(module),
    do: module.run(arguments, context, options)

  def run(%{impl: module}, arguments, context) when is_atom(module),
    do: module.run(arguments, context, [])

  @doc """
  Compensate a step
  """
  @spec compensate(
          Step.t(),
          reason :: any,
          arguments :: Reactor.inputs(),
          context :: Reactor.context()
        ) :: compensate_result()
  def compensate(%{impl: {module, options}}, reason, arguments, context) when is_atom(module),
    do: module.compensate(reason, arguments, context, options)

  def compensate(%{impl: module}, reason, arguments, context) when is_atom(module),
    do: module.compensate(reason, arguments, context, [])

  @doc """
  Undo a step
  """
  @spec undo(Step.t(), value :: any, arguments :: Reactor.inputs(), context :: Reactor.context()) ::
          undo_result()
  def undo(%{impl: {module, options}}, value, arguments, context) when is_atom(module),
    do: module.undo(value, arguments, context, options)

  def undo(%{impl: module}, value, arguments, context) when is_atom(module),
    do: module.undo(value, arguments, context, [])

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end
end
