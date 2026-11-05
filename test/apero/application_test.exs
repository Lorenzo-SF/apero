defmodule Apero.ApplicationTest do
  use ExUnit.Case, async: false

  describe "start/2" do
    test "starts the rate limit registry" do
      # The application was started by the test_helper.  Just verify
      # the registry is registered.
      assert Process.whereis(Apero.RateLimit.Registry) != nil
    end

    test "starts the rate limit supervisor" do
      assert Process.whereis(Apero.RateLimit.Supervisor) != nil
    end

    test "starts the cache supervisor (P0-3 fix)" do
      # P0-3: previously, Apero.Application only started the rate
      # limit supervisor.  The cache supervisor is now wired in to
      # provide the @adapters_table and the AdapterMonitor.
      assert Process.whereis(Apero.Cache.Supervisor) != nil
    end

    test "starts the cache adapter monitor" do
      # The monitor process is a child of Apero.Cache.Supervisor.
      assert Process.whereis(Apero.Cache.AdapterMonitor) != nil
    end

    test "@adapters_table is initialised at boot" do
      # No race condition: the table is created synchronously in
      # Application.start/2 BEFORE any cache adapter can be started.
      assert :ets.info(:apero_cache_adapters) != :undefined
    end
  end
end
