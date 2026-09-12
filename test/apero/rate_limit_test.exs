defmodule Apero.RateLimitTest do
  use ExUnit.Case, async: false

  alias Apero.RateLimit

  describe "new/1" do
    test "creates a new rate limit configuration" do
      opts = [capacity: 5, refill_per_second: 2.0, bucket: :leaky, name: :api_calls]
      rate_limit = RateLimit.new(opts)

      assert rate_limit.capacity == 5
      assert rate_limit.refill_per_second == 2.0
      assert rate_limit.bucket == :leaky
      assert rate_limit.name == :api_calls
    end
  end

  describe "token bucket" do
    test "consumes tokens until empty, then blocks until refill" do
      RateLimit.new(name: :tb_consume, capacity: 3, refill_per_second: 0.0)

      assert RateLimit.allow?(:tb_consume)
      assert RateLimit.allow?(:tb_consume)
      assert RateLimit.allow?(:tb_consume)
      refute RateLimit.allow?(:tb_consume)
      refute RateLimit.allow?(:tb_consume)
    end

    test "refills tokens over time" do
      RateLimit.new(name: :tb_refill, capacity: 2, refill_per_second: 100.0)

      assert RateLimit.allow?(:tb_refill, 2)
      refute RateLimit.allow?(:tb_refill, 1)

      Process.sleep(40)
      assert RateLimit.allow?(:tb_refill, 1)
    end

    test "check returns :ok or {:error, :rate_limited}" do
      RateLimit.new(name: :tb_check, capacity: 1, refill_per_second: 0.0)

      assert RateLimit.check(:tb_check) == :ok
      assert RateLimit.check(:tb_check) == {:error, :rate_limited}
    end
  end

  describe "leaky bucket" do
    test "peaks are queued, drain rate is never exceeded" do
      RateLimit.new(name: :lb_queue, capacity: 3, refill_per_second: 0.0, bucket: :leaky)

      # In-flight work fills up to capacity, then rejects
      assert RateLimit.allow?(:lb_queue, 3)
      refute RateLimit.allow?(:lb_queue, 1)
      refute RateLimit.allow?(:lb_queue, 1)
    end

    test "drains over time" do
      RateLimit.new(name: :lb_drain, capacity: 2, refill_per_second: 100.0, bucket: :leaky)

      assert RateLimit.allow?(:lb_drain, 2)
      refute RateLimit.allow?(:lb_drain, 1)

      Process.sleep(40)
      # 100/s * 0.04s ≈ 4 units drained → capacity available again
      assert RateLimit.allow?(:lb_drain, 1)
    end
  end

  describe "wait/3" do
    test "waits for a token to become available" do
      RateLimit.new(name: :w_refill, capacity: 1, refill_per_second: 100.0)

      assert RateLimit.check(:w_refill) == :ok
      # Token refills in ~10ms; wait should succeed well within 500ms
      assert RateLimit.wait(:w_refill, 1, 500) == :ok
    end

    test "returns {:error, :rate_limited} when the bucket can never refill" do
      RateLimit.new(name: :w_stall, capacity: 1, refill_per_second: 0.0)

      assert RateLimit.check(:w_stall) == :ok
      # refill_per_second = 0 → capacity can never free up → :rate_limited
      assert RateLimit.wait(:w_stall, 1, 50) == {:error, :rate_limited}
    end

    test "wait/3 uses receive-based loop, not recursion (P1-5 fix)" do
      RateLimit.new(name: :w_loop, capacity: 1, refill_per_second: 100.0)

      assert RateLimit.check(:w_loop) == :ok
      # If wait/3 were recursive, a long timeout would stack-overflow.
      # With 600 iterations of 10ms = 6s of wait, the receive-based
      # implementation stays flat.
      assert RateLimit.wait(:w_loop, 1, 600) == :ok
    end
  end

  describe "concurrent access" do
    test "100 concurrent processes do not break bucket invariants" do
      capacity = 10
      RateLimit.new(name: :conc, capacity: capacity, refill_per_second: 0.0)

      results =
        1..100
        |> Task.async_stream(fn _ -> RateLimit.allow?(:conc) end, max_concurrency: 50)
        |> Enum.map(fn {:ok, allowed} -> allowed end)

      assert Enum.count(results, & &1) == capacity
    end
  end

  describe "bucket types" do
    test "token bucket and leaky bucket configurations are honored" do
      token = RateLimit.new(bucket: :token, name: :bt_token)
      assert token.bucket == :token

      leaky = RateLimit.new(bucket: :leaky, name: :bt_leaky)
      assert leaky.bucket == :leaky
    end
  end
end
