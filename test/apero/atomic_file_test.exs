defmodule Apero.Atomic.FileTest do
  use ExUnit.Case, async: true

  alias Apero.Atomic.File, as: AtomicFile

  @base_dir Path.join(System.tmp_dir(), "apero-atomic-test-#{System.unique_integer([:positive])}")

  setup do
    File.mkdir_p!(@base_dir)
    on_exit(fn -> File.rm_rf(@base_dir) end)
    :ok
  end

  defp path(name), do: Path.join(@base_dir, name)

  describe "write/3" do
    test "writes content to file atomically" do
      file = path("hello.txt")

      assert AtomicFile.write(file, "hello") == :ok
      assert File.read(file) == {:ok, "hello"}
    end

    test "handles the fsync option" do
      file = path("fsync.txt")

      assert AtomicFile.write(file, "hello", fsync: true) == :ok
      assert File.read(file) == {:ok, "hello"}
    end

    test "overwrites existing content atomically" do
      file = path("overwrite.txt")

      assert AtomicFile.write(file, "v1") == :ok
      assert AtomicFile.write(file, "v2") == :ok
      assert File.read(file) == {:ok, "v2"}
    end

    test "returns error and leaves no temp file when target directory is missing" do
      missing_dir = Path.join(@base_dir, "does-not-exist")
      file = Path.join(missing_dir, "nested.txt")

      assert {:error, _reason} = AtomicFile.write(file, "hello")
      refute File.exists?(file)
      # No orphan .tmp anywhere in the base dir
      assert leftover_tmps() == []
    end

    test "leaves no temp files behind after success" do
      file = path("clean.txt")
      assert AtomicFile.write(file, "hello") == :ok
      assert leftover_tmps() == []
    end
  end

  describe "replace/3" do
    test "replaces file content with function result" do
      file = path("replace.txt")
      assert AtomicFile.write(file, "hello") == :ok

      assert AtomicFile.replace(file, fn content -> {:ok, String.upcase(content)} end) == :ok
      assert File.read(file) == {:ok, "HELLO"}
    end

    test "leaves original untouched when function returns error" do
      file = path("replace_error.txt")
      assert AtomicFile.write(file, "hello") == :ok

      assert AtomicFile.replace(file, fn _content -> {:error, :oops} end) == {:error, :oops}
      assert File.read(file) == {:ok, "hello"}
      assert leftover_tmps() == []
    end

    test "returns error when the file does not exist" do
      file = path("missing.txt")

      assert {:error, :enoent} = AtomicFile.replace(file, fn content -> {:ok, content} end)
    end
  end

  defp leftover_tmps do
    @base_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".tmp-"))
  end
end
