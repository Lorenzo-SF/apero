defmodule Apero.File.IO.WithLockCrashTest do
  use ExUnit.Case, async: false

  alias Apero.File.IO

  test "with_lock removes the lock file when fun raises (P0-4 fix)" do
    base = Path.join(System.tmp_dir!(), "apero_lock_crash_#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    lock = Path.join(base, "my.lock")

    assert_raise RuntimeError, fn ->
      IO.with_lock(lock, [timeout_ms: 1000, retry_ms: 50], fn ->
        raise "boom"
      end)
    end

    # The lock file must be cleaned up so the next attempt can acquire it.
    refute File.exists?(lock), "lock file should have been cleaned up after crash"
    File.rm_rf!(base)
  end

  test "with_lock removes the lock file when the linked process dies" do
    base = Path.join(System.tmp_dir!(), "apero_lock_linked_#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    lock = Path.join(base, "linked.lock")

    # Trap exits so a linked child crash does not kill the test process,
    # then assert that with_lock's try/after cleaned the lock file.
    Process.flag(:trap_exit, true)

    IO.with_lock(lock, [timeout_ms: 1000, retry_ms: 50], fn ->
      spawn_link(fn -> raise "linked child crash" end)
      Process.sleep(200)
      # Drain any EXIT messages so the test mailbox stays clean.
      receive do
        {:EXIT, _, _} -> :ok
      after
        0 -> :ok
      end
    end)

    refute File.exists?(lock), "lock file should have been cleaned up after linked crash"
    File.rm_rf!(base)
  end

  test "with_lock happy path still works" do
    base = Path.join(System.tmp_dir!(), "apero_lock_ok_#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    lock = Path.join(base, "ok.lock")

    assert :ok = IO.with_lock(lock, fn -> :ok end)
    refute File.exists?(lock)
    File.rm_rf!(base)
  end
end
