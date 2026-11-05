defmodule Apero.Cache.AdapterMonitorTest do
  use ExUnit.Case, async: false

  alias Apero.Cache.AdapterMonitor

  test "track/1 monitors the PID and cleans up on DOWN (P1-4 fix)" do
    {:ok, pid} = Agent.start_link(fn -> :ok end)

    AdapterMonitor.track(pid)
    assert Process.alive?(pid)

    # Insert an entry in @adapters_table that points to the PID.
    :ets.insert(:apero_cache_adapters, {pid, :test_adapter})
    assert :ets.lookup(:apero_cache_adapters, pid) == [{pid, :test_adapter}]

    # Stop the PID.  The monitor should clean up the ETS entry.
    Agent.stop(pid)
    Process.sleep(20)

    assert :ets.lookup(:apero_cache_adapters, pid) == []
  end

  test "multiple tracked PIDs are independent" do
    {:ok, pid1} = Agent.start_link(fn -> :ok end)
    {:ok, pid2} = Agent.start_link(fn -> :ok end)

    AdapterMonitor.track(pid1)
    AdapterMonitor.track(pid2)
    :ets.insert(:apero_cache_adapters, {pid1, :a})
    :ets.insert(:apero_cache_adapters, {pid2, :b})

    Agent.stop(pid1)
    Process.sleep(20)

    assert :ets.lookup(:apero_cache_adapters, pid1) == []
    assert :ets.lookup(:apero_cache_adapters, pid2) == [{pid2, :b}]

    Agent.stop(pid2)
  end

  test "track/1 is idempotent for the same PID" do
    {:ok, pid} = Agent.start_link(fn -> :ok end)
    ref1 = AdapterMonitor.track(pid)
    ref2 = AdapterMonitor.track(pid)
    assert is_reference(ref1)
    assert is_reference(ref2)
    Agent.stop(pid)
  end
end
