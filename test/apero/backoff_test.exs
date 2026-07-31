defmodule Apero.BackoffTest do
  use ExUnit.Case, async: true

  alias Apero.Backoff

  describe "new/4" do
    test "creates a backoff configuration with default values" do
      backoff = Backoff.new(100, 1000)

      assert backoff.base_ms == 100
      assert backoff.max_ms == 1000
      assert backoff.factor == 2.0
      assert backoff.jitter == :decorrelated
    end

    test "creates a backoff configuration with custom values" do
      backoff = Backoff.new(50, 500, 3.0, :full)

      assert backoff.base_ms == 50
      assert backoff.max_ms == 500
      assert backoff.factor == 3.0
      assert backoff.jitter == :full
    end
  end

  describe "delay/2" do
    test "full jitter delays stay within [0, max_ms]" do
      backoff = Backoff.new(100, 1000, 2.0, :full)

      for attempt <- 0..10 do
        for _ <- 1..50 do
          delay = Backoff.delay(backoff, attempt)
          assert delay >= 0
          assert delay <= 1000
        end
      end
    end

    test "decorrelated jitter delays stay within [0, max_ms]" do
      backoff = Backoff.new(100, 1000, 2.0, :decorrelated)

      for attempt <- 0..10 do
        for _ <- 1..50 do
          delay = Backoff.delay(backoff, attempt)
          assert delay >= 0
          assert delay <= 1000
        end
      end
    end

    test "full jitter never exceeds the exponential cap for that attempt" do
      backoff = Backoff.new(100, 30_000, 2.0, :full)

      # attempt 0: cap 100, attempt 1: cap 200, attempt 2: cap 400
      for {attempt, cap} <- [0, 1, 2] |> Enum.zip([100, 200, 400]) do
        for _ <- 1..100 do
          assert Backoff.delay(backoff, attempt) <= cap
        end
      end
    end

    test "deterministic with a fixed seed" do
      backoff = Backoff.new(100, 1000, 2.0, :full)

      :rand.seed(:exsss, {101, 102, 103})
      first = Enum.map(0..5, &Backoff.delay(backoff, &1))

      :rand.seed(:exsss, {101, 102, 103})
      second = Enum.map(0..5, &Backoff.delay(backoff, &1))

      assert first == second
    end

    test "average delay grows exponentially with attempt (full jitter)" do
      backoff = Backoff.new(100, 30_000, 2.0, :full)

      :rand.seed(:exsss, {1, 2, 3})

      avg_0 = average(fn -> Backoff.delay(backoff, 0) end, 200)
      avg_1 = average(fn -> Backoff.delay(backoff, 1) end, 200)
      avg_2 = average(fn -> Backoff.delay(backoff, 2) end, 200)
      avg_3 = average(fn -> Backoff.delay(backoff, 3) end, 200)

      assert avg_3 > avg_2
      assert avg_2 > avg_1
      assert avg_1 > avg_0
      # attempt N average ≈ base * factor^N / 2 → roughly doubles per attempt
      assert_in_delta avg_1, avg_0 * 2, avg_0 * 2
      assert_in_delta avg_2, avg_1 * 2, avg_1 * 2
    end
  end

  describe "sleep/2" do
    test "sleeps for the calculated delay" do
      backoff = Backoff.new(1, 10)

      assert Backoff.sleep(backoff, 0) == :ok
    end
  end

  defp average(fun, samples) do
    Enum.sum(for _ <- 1..samples, do: fun.()) / samples
  end
end
