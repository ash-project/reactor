defmodule Reactor.Dsl.PlanableVerifierTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.{Dsl.PlanableVerifier, Error.PlanError}

  test "is a Spark verifier" do
    assert Spark.implements_behaviour?(PlanableVerifier, Spark.Dsl.Verifier)
  end

  defmodule NoopStep do
    @moduledoc false
    use Reactor.Step

    def run(_, _, _), do: {:ok, :noop}
  end

  describe "verify/1" do
    test "refuses to compile cyclic reactors" do
      assert_raise PlanError, ~r/cyclic/i, fn ->
        defmodule DegenerateReactor do
          @moduledoc false
          use Reactor

          step :a, NoopStep do
            argument :b, result(:b)
          end

          step :b, NoopStep do
            argument :a, result(:a)
          end
        end
      end
    end
  end
end
