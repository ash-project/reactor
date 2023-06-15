defmodule Reactor.Container.AfterVerify do
  @moduledoc false
  alias Reactor.Error.ContainerError

  @message "Cannot define `before_steps/2` or `after_steps/2` in conjunction with `around_steps/3`"

  @doc false
  @spec __after_verify__(module) :: :ok | no_return
  def __after_verify__(module) do
    before_steps = function_exported?(module, :before_steps, 2)
    after_steps = function_exported?(module, :after_steps, 2)
    around_steps = function_exported?(module, :around_steps, 3)

    cond do
      around_steps && (before_steps || after_steps) ->
        raise ContainerError,
          container: module,
          message:
            "Cannot define `before_steps/2` or `after_steps/2` in conjunction with `around_steps/3`"

      before_steps && !after_steps ->
        raise ContainerError,
          container: module,
          message: "Cannot define `before_steps/2` and not `after_steps/2`"

      after_steps && !before_steps ->
        raise ContainerError,
          container: module,
          message: "Cannot define `after_steps/2` and not `before_steps/2`"

      !before_steps && !after_steps && !around_steps ->
        raise ContainerError,
          container: module,
          message: "Must define either `around_steps/3` or `before_steps/2`and `after_steps/2`"

      true ->
        :ok
    end
  end
end
