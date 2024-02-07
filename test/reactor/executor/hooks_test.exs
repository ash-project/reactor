defmodule Reactor.Executor.HooksTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Reactor.Builder

  describe "init" do
    defmodule ReturnContextReactor do
      @moduledoc false
      use Reactor

      step :return_context do
        run fn _args, context ->
          {:ok, context}
        end
      end
    end

    test "initialisation hooks can mutate the context" do
      reactor =
        ReturnContextReactor.reactor()
        |> Builder.on_init!(fn context ->
          {:ok, Map.put(context, :mutated?, true)}
        end)

      {:ok, context} = Reactor.run(reactor, %{}, %{mutated?: false})
      assert context.mutated?
    end
  end

  describe "halt" do
    defmodule HaltingReactor do
      @moduledoc false
      use Reactor

      step :halt do
        run fn _, _ ->
          {:halt, :because}
        end
      end
    end

    test "halt hooks can mutate the context" do
      reactor =
        HaltingReactor.reactor()
        |> Builder.on_halt!(fn context ->
          {:ok, Map.put(context, :mutated?, true)}
        end)

      {:halted, halted_reactor} = Reactor.run(reactor, %{}, %{mutated?: false})
      assert halted_reactor.context.mutated?
    end
  end

  describe "error" do
    defmodule ErrorReactor do
      @moduledoc false
      use Reactor

      step :fail do
        run &fail/2
      end

      def fail(_args, _context) do
        raise "hell"
      end
    end

    test "error hooks can mutate the error" do
      reactor =
        ErrorReactor.reactor()
        |> Builder.on_error!(fn errors, _ ->
          [error] = List.wrap(errors)
          assert is_exception(error, RuntimeError)
          assert Exception.message(error) == "hell"

          {:error, :wat}
        end)

      assert {:error, :wat} = Reactor.run(reactor, %{}, %{})
    end

    test "error hooks can see the context" do
      reactor =
        ErrorReactor.reactor()
        |> Builder.on_error!(fn _errors, context ->
          assert context.is_context?

          :ok
        end)

      assert {:error, [%RuntimeError{message: "hell"}]} =
               Reactor.run(reactor, %{}, %{is_context?: true})
    end
  end

  describe "complete" do
    defmodule SimpleReactor do
      @moduledoc false
      use Reactor

      step :succeed do
        run fn _, _ -> {:ok, :ok} end
      end
    end

    test "completion hooks can change the result" do
      reactor =
        SimpleReactor.reactor()
        |> Builder.on_complete!(fn :ok, _ ->
          {:ok, :wat}
        end)

      assert {:ok, :wat} = Reactor.run(reactor, %{}, %{})
    end

    test "completion hooks can see the context" do
      reactor =
        SimpleReactor.reactor()
        |> Builder.on_complete!(fn result, context ->
          assert context.is_context?
          {:ok, result}
        end)

      assert {:ok, :ok} = Reactor.run(reactor, %{}, %{is_context?: true})
    end
  end
end
