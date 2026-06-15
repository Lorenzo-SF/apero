defmodule Apero.File.IOTest do
  use ExUnit.Case, async: true

  alias Apero.File.IO

  describe "atomic_write/2" do
    test "writes content and creates parent dirs" do
      path =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_test_io_#{:erlang.unique_integer([:positive])}/nested/file.txt"
        )

      assert :ok = IO.atomic_write(path, "hello")
      assert File.read!(path) == "hello"

      File.rm_rf!(Path.dirname(Path.dirname(path)))
    end

    test "leaves no temp file on success" do
      dir =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_test_atomic_#{:erlang.unique_integer([:positive])}"
        )

      File.mkdir_p!(dir)
      path = Elixir.Path.join(dir, "test.txt")

      :ok = IO.atomic_write(path, "content")

      # No temp files should remain
      temp_files = File.ls!(dir) |> Enum.filter(&String.starts_with?(&1, ".apero_tmp"))
      assert temp_files == []

      File.rm_rf!(dir)
    end
  end

  describe "checksum/2" do
    test "streams file, returns sha256 hex" do
      path =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_cs_test_#{:erlang.unique_integer([:positive])}"
        )

      File.write!(path, "hello")

      {:ok, digest} = IO.checksum(path, :sha256)
      assert String.length(digest) == 64
      assert digest == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

      File.rm!(path)
    end

    test "is deterministic" do
      path =
        Elixir.Path.join(System.tmp_dir!(), "apero_cs_det_#{:erlang.unique_integer([:positive])}")

      File.write!(path, "hello")

      {:ok, digest1} = IO.checksum(path)
      {:ok, digest2} = IO.checksum(path)
      assert digest1 == digest2

      File.rm!(path)
    end

    test "different content, different digest" do
      path1 =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_cs_diff1_#{:erlang.unique_integer([:positive])}"
        )

      path2 =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_cs_diff2_#{:erlang.unique_integer([:positive])}"
        )

      File.write!(path1, "hello")
      File.write!(path2, "world")

      {:ok, d1} = IO.checksum(path1)
      {:ok, d2} = IO.checksum(path2)
      assert d1 != d2

      File.rm!(path1)
      File.rm!(path2)
    end

    test "returns error for missing file" do
      assert {:error, _} = IO.checksum("/nonexistent/path")
    end
  end

  describe "checksum_many/2" do
    test "computes checksums in parallel" do
      dir = System.tmp_dir!()
      path1 = Elixir.Path.join(dir, "apero_cs_m1_#{:erlang.unique_integer([:positive])}")
      path2 = Elixir.Path.join(dir, "apero_cs_m2_#{:erlang.unique_integer([:positive])}")
      File.write!(path1, "hello")
      File.write!(path2, "world")

      results = IO.checksum_many([path1, path2])

      assert is_map(results)
      assert {:ok, _} = results[path1]
      assert {:ok, _} = results[path2]

      File.rm!(path1)
      File.rm!(path2)
    end
  end

  describe "with_tmp_file/2" do
    test "creates and cleans up temp file" do
      parent = self()

      IO.with_tmp_file(fn path ->
        assert File.exists?(path)
        send(parent, {:path, path})
      end)

      receive do
        {:path, path} -> refute File.exists?(path)
      after
        1000 -> flunk("timeout")
      end
    end

    test "cleans up even when fun raises" do
      try do
        IO.with_tmp_file(fn path ->
          send(self(), {:path, path})
          throw(:error)
        end)
      catch
        _ -> :ok
      end

      receive do
        {:path, path} -> refute File.exists?(path)
      after
        1000 -> flunk("timeout")
      end
    end
  end

  describe "with_tmp_dir/2" do
    test "creates and cleans up temp directory" do
      parent = self()

      IO.with_tmp_dir(fn dir ->
        assert File.dir?(dir)
        send(parent, {:dir, dir})
      end)

      receive do
        {:dir, dir} -> refute File.dir?(dir)
      after
        1000 -> flunk("timeout")
      end
    end
  end

  describe "with_lock/3" do
    test "executes fun and cleans lock file" do
      lock_path =
        Elixir.Path.join(System.tmp_dir!(), "apero_lock_#{:erlang.unique_integer([:positive])}")

      result = IO.with_lock(lock_path, fn -> :result end)

      assert result == :result
      refute File.exists?(lock_path)
    end

    test "returns timeout error when lock is held" do
      lock_path =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_lock_timeout_#{:erlang.unique_integer([:positive])}"
        )

      # Start first lock holder
      task =
        Task.async(fn ->
          IO.with_lock(lock_path, [timeout_ms: 5000], fn ->
            Process.sleep(1000)
            :done
          end)
        end)

      # Try to acquire same lock immediately
      Process.sleep(100)
      result = IO.with_lock(lock_path, [timeout_ms: 100], fn -> :should_not_run end)

      assert result == {:error, :timeout}
      Task.await(task, 10_000)
      File.rm(lock_path)
    end
  end

  describe "disk_usage/1" do
    test "returns disk usage map" do
      assert {:ok, usage} = IO.disk_usage("/")
      assert is_map(usage)
      assert Map.has_key?(usage, :total_mb)
      assert Map.has_key?(usage, :used_mb)
      assert Map.has_key?(usage, :free_mb)
      assert Map.has_key?(usage, :use_pct)
    end
  end

  describe "copy_many/1" do
    test "copies multiple files in parallel" do
      dir = System.tmp_dir!()
      dir1 = Elixir.Path.join(dir, "apero_cm1_#{:erlang.unique_integer([:positive])}")
      dir2 = Elixir.Path.join(dir, "apero_cm2_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(dir1)
      File.mkdir_p!(dir2)

      src1 = Elixir.Path.join(dir1, "file1.txt")
      src2 = Elixir.Path.join(dir1, "file2.txt")
      dest1 = Elixir.Path.join(dir2, "file1.txt")
      dest2 = Elixir.Path.join(dir2, "file2.txt")

      File.write!(src1, "content1")
      File.write!(src2, "content2")

      results = IO.copy_many([{src1, dest1}, {src2, dest2}])

      assert length(results) == 2
      assert File.read!(dest1) == "content1"
      assert File.read!(dest2) == "content2"

      File.rm_rf!(dir1)
      File.rm_rf!(dir2)
    end
  end
end
