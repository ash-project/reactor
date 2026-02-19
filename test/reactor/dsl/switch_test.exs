# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
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

  describe "issue #273 - nested steps can refer to external step results with async execution" do
    defmodule SwitchExternalResultAsyncReactor do
      @moduledoc false
      use Reactor

      input :params

      step :create_personal_organization do
        run fn _, _ ->
          Process.sleep(10)
          {:ok, %{org_id: "org_123"}}
        end
      end

      step :create_session_token do
        run fn _, _ ->
          {:ok, "token_abc"}
        end
      end

      switch :populate_scope do
        on input(:params)

        matches? &(Map.get(&1, "invite_token") != nil) do
          step :populate_scope do
            argument :user_token, result(:create_session_token)
            wait_for :create_personal_organization

            run fn %{user_token: token}, _ ->
              {:ok, %{token: token, source: :invite}}
            end
          end
        end

        default do
          step :populate_scope do
            argument :user_token, result(:create_session_token)
            argument :scope, result(:create_personal_organization)

            run fn %{scope: scope, user_token: token}, _ ->
              {:ok, %{token: token, org_id: scope.org_id, source: :default}}
            end
          end
        end
      end

      return :populate_scope
    end

    test "when switch nested steps depend on external results, they are resolved correctly with async execution" do
      assert {:ok, result} =
               Reactor.run(SwitchExternalResultAsyncReactor, %{params: %{}}, %{}, async?: true)

      assert result.source == :default
      assert result.org_id == "org_123"
      assert result.token == "token_abc"
    end

    test "when switch nested steps depend on external results via wait_for, they are resolved correctly" do
      assert {:ok, result} =
               Reactor.run(
                 SwitchExternalResultAsyncReactor,
                 %{params: %{"invite_token" => "inv_123"}},
                 %{},
                 async?: true
               )

      assert result.source == :invite
      assert result.token == "token_abc"
    end
  end
end
