defmodule Reactor.Error.ContainerError do
  defexception [:module, :message]

  @impl true
  def exception(attrs), do: struct(__MODULE__, attrs)

  @impl true
  def message(error) do
    """
    # Container Error `#{inspect(error.module)}`

    #{error.message}
    """
  end
end
