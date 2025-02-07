defmodule Reactor.Builder.Compose do
  @moduledoc """
  Handle composition of Reactors for the builder.

  The composition logic was getting complicated enough that it seemed sensible
  to extract it from the builder - if only to aid readability.

  You should not use this module directly, but instead use
  `Reactor.Builder.compose/4`.
  """
  import Reactor, only: :macros
  import Reactor.Argument, only: :macros
  import Reactor.Utils
  alias Reactor.{Argument, Builder, Error.Internal.ComposeError, Step}

  @opt_schema Spark.Options.new!(
                guards: [
                  type: {:list, {:protocol, Reactor.Guard.Build}},
                  required: false,
                  default: []
                ],
                runtime?: [
                  type: {:in, [nil, true]},
                  required: false
                ]
              )

  @doc """
  Compose another Reactor inside this one.

  ## Options

  #{Spark.Options.docs(@opt_schema)}
  """
  @spec compose(Reactor.t(), atom, Reactor.t() | module, [Builder.step_argument()], keyword) ::
          {:ok, Reactor.t()} | {:error, any}
  def compose(reactor, name, inner_reactor, arguments, options) when is_atom(inner_reactor) do
    case verify_arguments(inner_reactor, arguments) do
      :ok ->
        Builder.add_step(
          reactor,
          name,
          {Reactor.Step.Compose, reactor: inner_reactor},
          arguments,
          async?: options[:async?],
          guards: options[:guards] || [],
          max_retries: 0,
          ref: :step_name
        )

      {:error, {:extra_args, inputs, extra_args}} ->
        {:error, :wat}

      {:error, {:missing_args, inputs, missing_args}} ->
        {:error, :wat}
    end
  end

  @doc "Verify that the arguments and reactor inputs match"
  @spec verify_arguments(Reactor.t(), [Builder.step_argument()]) ::
          :ok | {:error, {:extra_args | :missing_args, MapSet.t(), MapSet.t()}}
  def verify_arguments(reactor, arguments) do
    with {:ok, inputs} <- reactor_inputs(reactor),
         {:ok, arg_names} <- argument_names(arguments) do
      extra_args =
        arg_names
        |> MapSet.difference(inputs)
        |> Enum.to_list()

      missing_args =
        inputs
        |> MapSet.difference(arg_names)
        |> Enum.to_list()

      case {extra_args, missing_args} do
        {[], []} ->
          :ok

        {extra_args, []} ->
          {:error, {:extra_args, inputs, extra_args}}

        {[], missing_args} ->
          {:error, {:missing_args, inputs, missing_args}}
      end
    end
  end

  defp reactor_inputs(reactor) when is_struct(reactor),
    do: {:ok, MapSet.new(reactor.inputs)}

  defp reactor_inputs(reactor) when is_atom(reactor) do
    with {:ok, reactor} <- Reactor.Info.to_struct(reactor) do
      reactor_inputs(reactor)
    end
  end

  defp argument_names(arguments), do: {:ok, MapSet.new(arguments, & &1.name)}
end
