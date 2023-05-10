defmodule Example.CyclicReactor do
  @moduledoc false
  use Reactor

  defmodule Noop do
    use Reactor.Step

    def can?(_), do: false

    @moduledoc false
    def run(_, _, _), do: {:ok, :noop}
  end

  step :a, Noop do
    argument :b, result(:b)
  end

  step :b, Noop do
    argument :a, result(:a)
  end
end
