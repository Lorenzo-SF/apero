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
end
