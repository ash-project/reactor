# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Middleware.TelemetryTest do
  @moduledoc false
  use ExUnit.Case, async: true

  setup(context) do
    table =
      :ets.new(context.test, [:public, :ordered_set])

    :telemetry.attach_many(
      to_string(context.test),
      [
        [:reactor, :run, :start],
        [:reactor, :run, :stop],
        [:reactor, :step, :process, :start],
        [:reactor, :step, :process, :stop],
        [:reactor, :step, :run, :start],
        [:reactor, :step, :run, :stop],
        [:reactor, :step, :compensate, :start],
        [:reactor, :step, :compensate, :stop],
        [:reactor, :step, :undo, :start],
        [:reactor, :step, :undo, :stop]
      ],
      &__MODULE__.handler/4,
      table
    )

    on_exit(fn ->
      :telemetry.detach(to_string(context.test))
    end)

    {:ok, table: table}
  end

  def handler(event, measurements, metadata, table) do
    :ets.insert(
      table,
      {measurements.system_time, %{event: event, measurements: measurements, metadata: metadata}}
    )
  end

  def get_events(table) do
    Process.sleep(200)

    table
    |> :ets.tab2list()
    |> Enum.map(&elem(&1, 1))
  end

  test "step run events", %{table: table} do
    defmodule SuccessfulStepReactor do
      @moduledoc false
      use Reactor

      middlewares do
        middleware Reactor.Middleware.Telemetry
      end

      step :noop do
        argument :marty, value(:mcfly)
        run fn _, _ -> {:ok, :noop} end
      end

      return :noop
    end

    start_time = System.monotonic_time()

    {:ok, :noop} = Reactor.run(SuccessfulStepReactor)

    expected_duration =
      System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

    events = get_events(table)

    assert [
             [:reactor, :run, :start],
             [:reactor, :step, :process, :start],
             [:reactor, :step, :run, :start],
             [:reactor, :step, :run, :stop],
             [:reactor, :step, :process, :stop],
             [:reactor, :run, :stop]
           ] = Enum.map(events, & &1.event)

    [run_start, _, _, step_stop, _, run_stop] = events

    assert run_start.metadata.id == SuccessfulStepReactor
    assert run_start.metadata.inputs == []
    assert run_start.metadata.middleware == [Reactor.Middleware.Telemetry]
    assert run_start.metadata.step_count == 1

    assert run_stop.metadata.status == :ok
    assert run_stop.metadata.result == :noop

    run_duration_in_millis =
      System.convert_time_unit(run_stop.measurements.duration, :native, :millisecond)

    assert_in_delta run_duration_in_millis, expected_duration, 100
    assert run_duration_in_millis <= expected_duration

    step_duration_in_millis =
      System.convert_time_unit(step_stop.measurements.duration, :native, :millisecond)

    assert step_duration_in_millis <= run_duration_in_millis
    assert_in_delta step_duration_in_millis, expected_duration, 100
  end

  test "step compensation events", %{table: table} do
    defmodule CompensationReactor do
      @moduledoc false
      use Reactor

      middlewares do
        middleware Reactor.Middleware.Telemetry
      end

      step :fail do
        run fn _, _ -> raise "hell" end
        compensate fn _, _ -> :ok end
      end
    end

    {:error, _} = Reactor.run(CompensationReactor)

    events = get_events(table)

    assert [
             [:reactor, :run, :start],
             [:reactor, :step, :process, :start],
             [:reactor, :step, :run, :start],
             [:reactor, :step, :run, :stop],
             [:reactor, :step, :compensate, :start],
             [:reactor, :step, :compensate, :stop],
             [:reactor, :step, :process, :stop],
             [:reactor, :run, :stop]
           ] = Enum.map(events, & &1.event)
  end

  test "step undo events", %{table: table} do
    defmodule UndoReactor do
      @moduledoc false
      use Reactor

      middlewares do
        middleware Reactor.Middleware.Telemetry
      end

      step :noop do
        run fn _, _ ->
          {:ok, :noop}
        end

        undo fn _ ->
          :ok
        end
      end

      step :fail do
        wait_for :noop

        run fn _, _ ->
          raise "hell"
        end
      end
    end

    {:error, _} = Reactor.run(UndoReactor)

    events = get_events(table)

    assert [
             [:reactor, :run, :start],
             [:reactor, :step, :process, :start],
             [:reactor, :step, :run, :start],
             [:reactor, :step, :run, :stop],
             [:reactor, :step, :process, :stop],
             [:reactor, :step, :process, :start],
             [:reactor, :step, :run, :start],
             [:reactor, :step, :run, :stop],
             [:reactor, :step, :process, :stop],
             [:reactor, :step, :undo, :start],
             [:reactor, :step, :undo, :stop],
             [:reactor, :run, :stop]
           ] = Enum.map(events, & &1.event)
  end
end
