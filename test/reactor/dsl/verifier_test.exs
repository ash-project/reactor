defmodule Reactor.Dsl.VerifierTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Spark.Error.DslError

  test "reactors cannot have duplicated step names" do
    assert_raise(DslError, ~r/duplicate steps/, fn ->
      defmodule DuplicatedStepNameReactor do
        @moduledoc false
        use Reactor

        step :example, Example.Step.Greeter
        step :example, Example.Step.Greeter
      end
    end)
  end

  test "reactors cannot have recursively duplicated step names" do
    assert_raise(DslError, ~r/duplicate steps/, fn ->
      defmodule RecursivelyDuplicatedStepNameReactor do
        @moduledoc false
        use Reactor

        step :example, Example.Step.Greeter

        group :group do
          before_all &{:ok, &1, &2, &3}
          after_all &{:ok, &1}

          step :example, Example.Step.Greeter
        end
      end
    end)
  end
end
