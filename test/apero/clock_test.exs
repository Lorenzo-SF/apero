defmodule Apero.ClockTest do
  use ExUnit.Case, async: true

  alias Apero.Clock

  describe "now/0" do
    test "returns current UTC date and time" do
      dt = Clock.now()
      assert is_struct(dt, DateTime)
      assert dt.zone_abbr == "UTC"
    end
  end

  describe "monotonic_ms/0" do
    test "returns monotonic time in milliseconds" do
      time1 = Clock.monotonic_ms()
      time2 = Clock.monotonic_ms()

      # Should be increasing or equal (monotonic)
      assert time1 <= time2
    end
  end

  describe "with_fixed/2" do
    test "executes function with fixed time" do
      fixed_time = ~U[2026-07-31 14:00:00.000000Z]

      result = Clock.with_fixed(fixed_time, fn -> Clock.now() end)

      assert result == fixed_time
    end
  end

  describe "set_fixed!/1" do
    test "sets fixed time globally" do
      fixed_time = ~U[2026-07-31 14:00:00.000000Z]

      Clock.set_fixed!(fixed_time)
      result = Clock.now()
      assert result == fixed_time

      # Restore normal behavior
      Clock.set_fixed!(nil)
      assert is_struct(Clock.now(), DateTime)
    end

    test "restores normal behavior when set to nil" do
      fixed_time = ~U[2026-07-31 14:00:00.000000Z]

      Clock.set_fixed!(fixed_time)
      assert Clock.now() == fixed_time

      Clock.set_fixed!(nil)
      assert is_struct(Clock.now(), DateTime)
    end
  end
end
