defmodule Apero.RetryTest do
  use ExUnit.Case, async: false

  alias Apero.Retry

  setup do
    # Flush any leftover messages from previous tests
    flush()
    :ok
  end

  defp flush do
    receive do
      _ -> flush()
    after
      0 -> :ok
    end
  end

  describe "with/2" do
    test "returns the first result if it does not match the predicate" do
      result = Retry.with(fn -> :ok end, retry_on: fn _ -> false end)
      assert result == :ok
    end

    test "retries up to max_attempts" do
      counter = :counters.new(1, [])

      result =
        Retry.with(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, :transient}
          end,
          max_attempts: 3,
          base_delay: 1,
          max_delay: 1,
          retry_on: fn
            {:error, _} -> true
            _ -> false
          end
        )

      assert result == {:error, :transient}
      # 1 initial attempt + 2 retries = 3 calls
      assert :counters.get(counter, 1) == 3
    end

    test "stops retrying when result is acceptable" do
      counter = :counters.new(1, [])

      result =
        Retry.with(
          fn ->
            :counters.add(counter, 1, 1)
            count = :counters.get(counter, 1)

            if count >= 2 do
              {:ok, "done"}
            else
              {:error, :retry}
            end
          end,
          max_attempts: 5,
          base_delay: 1,
          max_delay: 1,
          retry_on: fn
            {:error, _} -> true
            _ -> false
          end
        )

      assert result == {:ok, "done"}
      assert :counters.get(counter, 1) == 2
    end

    test "calls on_retry callback between attempts" do
      test_pid = self()
      counter = :counters.new(1, [])

      Retry.with(
        fn ->
          :counters.add(counter, 1, 1)
          {:error, :boom}
        end,
        max_attempts: 3,
        base_delay: 1,
        max_delay: 1,
        retry_on: fn
          {:error, _} -> true
          _ -> false
        end,
        on_retry: fn meta ->
          send(test_pid, {:retried, meta.attempt, meta.result})
        end
      )

      # Should have received 2 retry callbacks (after attempt 1 and 2)
      assert_received {:retried, 1, {:error, :boom}}
      assert_received {:retried, 2, {:error, :boom}}
    end

    test "uses default retry predicate (5xx and {:error, _})" do
      assert Retry.with(fn -> :ok end) == :ok
      assert Retry.with(fn -> {:error, :x} end) == {:error, :x}
      assert Retry.with(fn -> {:ok, %{status: 200}} end) == {:ok, %{status: 200}}
      # 5xx should retry until max_attempts
      counter = :counters.new(1, [])

      result =
        Retry.with(
          fn ->
            :counters.add(counter, 1, 1)
            {:ok, %{status: 503}}
          end,
          max_attempts: 2,
          base_delay: 1,
          max_delay: 1
        )

      assert result == {:ok, %{status: 503}}
      assert :counters.get(counter, 1) == 2
    end
  end

  describe "schedule_next/7" do
    test "sends a retry message after delay" do
      Retry.schedule_next(
        fn -> :ok end,
        1,
        3,
        10,
        1000,
        fn _ -> true end,
        fn _ -> :ok end
      )

      assert_receive {:apero_retry, _, 2, 3, 10, 1000, _, _}, 100
    end

    test "does not send a message when attempt >= max" do
      Retry.schedule_next(
        fn -> :ok end,
        5,
        3,
        10,
        1000,
        fn _ -> true end,
        fn _ -> :ok end
      )

      refute_receive {:apero_retry, _, _, _, _, _, _, _}, 50
    end

    test "calls on_retry callback" do
      test_pid = self()

      Retry.schedule_next(
        fn -> :ok end,
        1,
        3,
        10,
        1000,
        fn _ -> true end,
        fn meta -> send(test_pid, {:on_retry, meta.attempt, meta.delay}) end
      )

      assert_receive {:on_retry, 1, _}, 50
    end
  end

  describe "handle_message/1" do
    test "returns {:apero_retry_done, result} when should_retry? returns false" do
      result =
        Retry.handle_message(
          {:apero_retry, fn -> {:ok, "success"} end, 2, 5, 10, 1000, fn _ -> false end,
           fn _ -> :ok end}
        )

      assert result == {:apero_retry_done, {:ok, "success"}}
    end

    test "returns {:apero_retry_done, result} when attempt >= max" do
      result =
        Retry.handle_message(
          {:apero_retry, fn -> {:error, :fail} end, 5, 5, 10, 1000, fn _ -> true end,
           fn _ -> :ok end}
        )

      assert result == {:apero_retry_done, {:error, :fail}}
    end

    test "schedules next attempt and returns {:apero_retry_pending, next_attempt} when should retry" do
      result =
        Retry.handle_message(
          {:apero_retry, fn -> {:error, :fail} end, 2, 5, 10, 1000, fn _ -> true end,
           fn _ -> :ok end}
        )

      assert result == {:apero_retry_pending, 3}
      assert_receive {:apero_retry, _, 3, 5, 10, 1000, _, _}, 100
    end
  end

  describe "non-blocking integration" do
    test "with N failures then success" do
      counter = :counters.new(1, [])

      attempt_fun = fn ->
        :counters.add(counter, 1, 1)
        count = :counters.get(counter, 1)

        if count >= 3 do
          {:ok, "done"}
        else
          {:error, :not_yet}
        end
      end

      Retry.schedule_next(
        attempt_fun,
        1,
        5,
        10,
        1000,
        fn
          {:error, _} -> true
          _ -> false
        end,
        fn _ -> :ok end
      )

      assert_receive {:apero_retry, fun, 2, 5, 10, 1000, should_retry?, on_retry}, 100

      # Handle attempt 2 (fails)
      result1 = Retry.handle_message({:apero_retry, fun, 2, 5, 10, 1000, should_retry?, on_retry})
      assert result1 == {:apero_retry_pending, 3}
      assert_receive {:apero_retry, _, 3, 5, 10, 1000, _, _}, 100

      # Handle attempt 3 (fails)
      result2 = Retry.handle_message({:apero_retry, fun, 3, 5, 10, 1000, should_retry?, on_retry})
      assert result2 == {:apero_retry_pending, 4}
      assert_receive {:apero_retry, _, 4, 5, 10, 1000, _, _}, 100

      # Handle attempt 4 (succeeds - count >= 3 now)
      result3 = Retry.handle_message({:apero_retry, fun, 4, 5, 10, 1000, should_retry?, on_retry})
      assert result3 == {:apero_retry_done, {:ok, "done"}}
    end
  end
end
