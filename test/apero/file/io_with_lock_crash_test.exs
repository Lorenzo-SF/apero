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

    # Spawn a process that links to ours and dies inside the lock.
    assert_raise RuntimeError, fn ->
      IO.with_lock(lock, timeout_ms: 1000, retry_ms: 50, fn ->
        spawn_link(fn -> raise "linked child crash" end)
        Process.sleep(100)
        # The linked crash propagates as an EXIT signal.
        receive do
        end
      end)
    end

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
