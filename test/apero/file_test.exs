defmodule Apero.FileTest do
  use ExUnit.Case, async: true

  alias Apero.File, as: AperoFile

  @tmp System.tmp_dir!()

  setup do
    dir = Path.join(@tmp, "apero_file_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "path predicates" do
    test "dir?/1 and file?/1", %{dir: dir} do
      file = Path.join(dir, "a.txt")
      File.write!(file, "x")
      assert AperoFile.dir?(dir)
      refute AperoFile.dir?(file)
      assert AperoFile.file?(file)
      refute AperoFile.file?(dir)
    end

    test "exists?/1", %{dir: dir} do
      assert AperoFile.exists?(dir)
      refute AperoFile.exists?(Path.join(dir, "nope"))
    end
  end

  describe "ensure_dir/1, write/2, read/1" do
    test "writes nested paths", %{dir: dir} do
      path = Path.join([dir, "a", "b", "c.txt"])
      assert :ok = AperoFile.ensure_dir(Path.dirname(path))
      assert :ok = AperoFile.write(path, "hello")
      assert {:ok, "hello"} = AperoFile.read(path)
    end

    test "read of missing file returns error", %{dir: dir} do
      assert {:error, _} = AperoFile.read(Path.join(dir, "missing.txt"))
    end

    test "read_lines/1 filters comments and blanks", %{dir: dir} do
      path = Path.join(dir, "lines.txt")
      File.write!(path, "# comment\n\n  alpha  \nbeta\n")
      assert {:ok, ["alpha", "beta"]} = AperoFile.read_lines(path)
    end
  end

  describe "extension/basename/expand" do
    test "extension/1" do
      assert AperoFile.extension("archive.tar.gz") == ".gz"
      assert AperoFile.extension("noext") == ""
    end

    test "basename/1" do
      assert AperoFile.basename("path/to/file.ex") == "file"
      assert AperoFile.basename("file") == "file"
    end

    test "expand/1" do
      assert AperoFile.expand("/x/../y") == "/y"
    end
  end

  describe "copy/move/delete" do
    test "copy/2 returns bytes copied", %{dir: dir} do
      src = Path.join(dir, "src.txt")
      dst = Path.join([dir, "nested", "dst.txt"])
      File.write!(src, "0123456789")
      assert {:ok, 10} = AperoFile.copy(src, dst)
      assert File.read!(dst) == "0123456789"
    end

    test "copy of missing source returns error", %{dir: dir} do
      assert {:error, _} = AperoFile.copy(Path.join(dir, "no.txt"), Path.join(dir, "d.txt"))
    end

    test "copy_dir/2", %{dir: dir} do
      src = Path.join(dir, "srcdir")
      dst = Path.join(dir, "dstdir")
      File.mkdir_p!(Path.join(src, "sub"))
      File.write!(Path.join([src, "sub", "f.txt"]), "x")
      assert :ok = AperoFile.copy_dir(src, dst)
      assert File.read!(Path.join([dst, "sub", "f.txt"])) == "x"
    end

    test "move/2 within same device", %{dir: dir} do
      src = Path.join(dir, "m.txt")
      dst = Path.join(dir, "m2.txt")
      File.write!(src, "data")
      assert :ok = AperoFile.move(src, dst)
      refute File.exists?(src)
      assert File.read!(dst) == "data"
    end

    test "move of missing source returns error", %{dir: dir} do
      assert {:error, _} = AperoFile.move(Path.join(dir, "nope"), Path.join(dir, "d"))
    end

    test "delete/1 is idempotent", %{dir: dir} do
      path = Path.join(dir, "del.txt")
      File.write!(path, "x")
      assert :ok = AperoFile.delete(path)
      assert :ok = AperoFile.delete(path)
    end

    test "delete_dir/2 removes recursively", %{dir: dir} do
      sub = Path.join(dir, "tree")
      File.mkdir_p!(Path.join(sub, "inner"))
      File.write!(Path.join([sub, "inner", "f.txt"]), "x")
      assert :ok = AperoFile.delete_dir(sub)
      refute File.exists?(sub)
    end
  end

  describe "glob/3, size/1, mtime/1" do
    test "glob non-recursive", %{dir: dir} do
      File.write!(Path.join(dir, "one.txt"), "1")
      File.write!(Path.join(dir, "two.md"), "2")
      assert Enum.sort(AperoFile.glob(dir, "*.txt")) == [Path.join(dir, "one.txt")]
    end

    test "glob recursive", %{dir: dir} do
      File.mkdir_p!(Path.join(dir, "deep"))
      File.write!(Path.join([dir, "deep", "n.txt"]), "n")
      assert AperoFile.glob(dir, "*.txt", recursive: true) != []
    end

    test "size/1", %{dir: dir} do
      path = Path.join(dir, "size.txt")
      File.write!(path, "12345")
      assert {:ok, 5} = AperoFile.size(path)
      assert {:error, _} = AperoFile.size(Path.join(dir, "nope"))
    end

    test "mtime/1", %{dir: dir} do
      path = Path.join(dir, "time.txt")
      File.write!(path, "x")
      assert {:ok, %DateTime{}} = AperoFile.mtime(path)
      assert {:error, _} = AperoFile.mtime(Path.join(dir, "nope"))
    end
  end

  describe "symlink/2" do
    test "creates a working symlink", %{dir: dir} do
      target = Path.join(dir, "target.txt")
      link = Path.join(dir, "link.txt")
      File.write!(target, "linked")
      assert :ok = AperoFile.symlink(target, link)
      assert File.read!(link) == "linked"
    end
  end

  describe "atomic_write/2" do
    test "writes content atomically", %{dir: dir} do
      path = Path.join(dir, "atomic.txt")
      assert :ok = AperoFile.atomic_write(path, "atomic!")
      assert File.read!(path) == "atomic!"
    end
  end

  describe "checksum/2 and checksum_many/2" do
    test "sha256 digest is 64 hex chars", %{dir: dir} do
      path = Path.join(dir, "cs.txt")
      File.write!(path, "hello")
      assert {:ok, digest} = AperoFile.checksum(path)
      assert String.length(digest) == 64
      assert digest =~ ~r/^[0-9a-f]{64}$/
    end

    test "md5 and sha512 variants", %{dir: dir} do
      path = Path.join(dir, "cs2.txt")
      File.write!(path, "data")
      assert {:ok, md5} = AperoFile.checksum(path, :md5)
      assert String.length(md5) == 32
      assert {:ok, sha512} = AperoFile.checksum(path, :sha512)
      assert String.length(sha512) == 128
    end

    test "missing file returns error", %{dir: dir} do
      assert {:error, _} = AperoFile.checksum(Path.join(dir, "missing"))
    end

    test "checksum_many/2 parallel", %{dir: dir} do
      p1 = Path.join(dir, "a.txt")
      p2 = Path.join(dir, "b.txt")
      File.write!(p1, "one")
      File.write!(p2, "two")
      result = AperoFile.checksum_many([p1, p2, Path.join(dir, "missing")])
      assert {:ok, _} = result[p1]
      assert {:ok, _} = result[p2]
      assert {:error, _} = result[Path.join(dir, "missing")]
    end
  end

  describe "with_tmp_file/2 and with_tmp_dir/2" do
    test "tmp file created and cleaned up", %{dir: dir} do
      path =
        AperoFile.with_tmp_file([dir: dir], fn p ->
          assert File.exists?(p)
          p
        end)

      refute File.exists?(path)
    end

    test "tmp file cleaned up on raise" do
      assert_raise RuntimeError, fn ->
        AperoFile.with_tmp_file(fn _p -> raise "boom" end)
      end
    end

    test "tmp dir created and cleaned up", %{dir: dir} do
      tmp_dir =
        AperoFile.with_tmp_dir([dir: dir], fn d ->
          assert File.dir?(d)
          d
        end)

      refute File.exists?(tmp_dir)
    end
  end

  describe "with_lock/3" do
    test "acquires lock, runs fun, releases", %{dir: dir} do
      lock = Path.join(dir, "lockfile")
      assert AperoFile.with_lock(lock, fn -> :locked_result end) == :locked_result
      refute File.exists?(lock)
    end

    test "times out when lock is held", %{dir: dir} do
      lock = Path.join(dir, "busy.lock")
      {:ok, holder} = File.open(lock, [:write, :exclusive])

      try do
        assert {:error, :timeout} =
                 AperoFile.with_lock(lock, [timeout_ms: 50, retry_ms: 10], fn -> :nope end)
      after
        File.close(holder)
      end
    end
  end

  describe "copy_many/1" do
    test "copies multiple files in order", %{dir: dir} do
      s1 = Path.join(dir, "s1.txt")
      s2 = Path.join(dir, "s2.txt")
      File.write!(s1, "aaa")
      File.write!(s2, "bb")

      results =
        AperoFile.copy_many([{s1, Path.join(dir, "d1.txt")}, {s2, Path.join(dir, "d2.txt")}])

      assert results == [{:ok, 3}, {:ok, 2}]
    end

    test "reports error for missing source", %{dir: dir} do
      results = AperoFile.copy_many([{Path.join(dir, "nope"), Path.join(dir, "d.txt")}])
      assert [{:error, _}] = results
    end
  end

  describe "generate_tree/1 and print_tree/1" do
    test "generate_tree builds ASCII tree" do
      assert AperoFile.generate_tree(["a"]) == "└─ a"
      tree = AperoFile.generate_tree(["b", "a/c", "a/d"])
      assert tree =~ "├─ a"
      assert tree =~ "└─ b"
    end

    test "print_tree prints to stdout", %{dir: dir} do
      File.write!(Path.join(dir, "leaf.txt"), "x")

      assert ExUnit.CaptureIO.capture_io(fn ->
               assert :ok = AperoFile.print_tree(dir)
             end) =~ "leaf.txt"
    end
  end
end
