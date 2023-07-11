defmodule Reactor.Dsl.StreamTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule StreamReactor do
    @moduledoc false
    use Reactor

    input :low
    input :high

    stream :only_primes do
      generator do
        argument :low, input(:low)
        argument :high, input(:high)

        run fn %{low: low, high: high} ->
          Range.new(low, high)
        end
      end

      filter do
        argument :element, element(:only_primes)

        predicate(fn
          %{element: 1} ->
            true

          %{element: 2} ->
            false

          %{element: element} ->
            2
            |> round(element / 2)
            |> Enum.any?(&rem(element, &1))
        end)
      end
    end
  end
end
