# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.SwitchTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule Noop do
    @moduledoc false
    use Reactor.Step

    def run(_, context, _), do: {:ok, context.current_step.name}
  end

  defmodule SwitchReactor do
    @moduledoc false
    use Reactor

    input :value

    switch :is_truthy? do
      on input(:value)

      matches? &(&1 in [nil, false]) do
        step :falsy, Noop

        return :falsy
      end

      default do
        step :truthy, Noop

        return :truthy
      end
    end

    return :is_truthy?
  end

  defmodule SwitchNoDefaultReactor do
    @moduledoc false
    use Reactor

    input :value

    switch :is_nil? do
      on input(:value)

      matches? &is_nil/1 do
        step :falsy, Noop
      end
    end
  end

  test "when provided a falsy value it works" do
    assert {:ok, :falsy} = Reactor.run(SwitchReactor, value: nil)
  end

  test "when provided a truthy value it works" do
    assert {:ok, :truthy} = Reactor.run(SwitchReactor, value: :marty)
  end

  test "it does not require a default" do
    assert {:ok, nil} = Reactor.run(SwitchNoDefaultReactor, value: nil)
  end

  describe "nested steps can refer to external inputs" do
    defmodule SwitchOutsideReferInputReactor do
      @moduledoc false
      use Reactor

      input :code

      switch :has_code do
        on input(:code)

        matches? &(not is_nil(&1)) do
          debug :debug do
            argument :onboarding_code, input(:code)
          end
        end
      end
    end

    test "when the switch matches it runs the inner step" do
      assert capture_log(fn ->
               Reactor.run(SwitchOutsideReferInputReactor, %{code: "amscray"})
             end) =~ ~r/amscray/
    end
  end

  describe "nested steps can refer to external step results" do
    defmodule SwitchOutsideReferResultReactor do
      @moduledoc false
      use Reactor

      input :code

      step :onboarding_code do
        argument :code, input(:code)
        run &{:ok, &1.code}
      end

      switch :has_code do
        on result(:onboarding_code)

        matches? &(not is_nil(&1)) do
          debug :debug do
            argument :onboarding_code, result(:onboarding_code)
          end
        end
      end
    end

    test "when the switch matches it runs the inner step" do
      assert capture_log(fn ->
               Reactor.run(SwitchOutsideReferResultReactor, %{code: "amscray"}, %{},
                 async?: false
               )
             end) =~ ~r/amscray/
    end
  end
end
