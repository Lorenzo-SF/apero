defmodule Apero.File.PathTest do
  use ExUnit.Case, async: true

  alias Apero.File.Path

  describe "dir?/1" do
    test "returns true for directories" do
      assert Path.dir?(System.tmp_dir!()) == true
    end

    test "returns false for files" do
      path =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_path_test_#{:erlang.unique_integer([:positive])}"
        )

      File.write!(path, "content")
      assert Path.dir?(path) == false
      File.rm!(path)
    end

    test "returns false for non-existent paths" do
      assert Path.dir?("/nonexistent/path") == false
    end
  end

  describe "file?/1" do
    test "returns true for regular files" do
      path =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_file_test_#{:erlang.unique_integer([:positive])}"
        )

      File.write!(path, "content")
      assert Path.file?(path) == true
      File.rm!(path)
    end

    test "returns false for directories" do
      assert Path.file?(System.tmp_dir!()) == false
    end
  end

  describe "exists?/1" do
    test "returns true for existing files" do
      path =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_exists_test_#{:erlang.unique_integer([:positive])}"
        )

      File.write!(path, "content")
      assert Path.exists?(path) == true
      File.rm!(path)
    end

    test "returns false for non-existent paths" do
      assert Path.exists?("/nonexistent/path") == false
    end
  end

  describe "ensure_dir/1" do
    test "creates directory and parents" do
      base =
        Elixir.Path.join(System.tmp_dir!(), "apero_ensure_#{:erlang.unique_integer([:positive])}")

      nested = Elixir.Path.join([base, "a", "b", "c"])

      assert :ok = Path.ensure_dir(nested)
      assert File.dir?(nested)

      File.rm_rf!(base)
    end
  end

  describe "symlink/2" do
    test "creates symlink" do
      target =
        Elixir.Path.join(System.tmp_dir!(), "apero_sym_t_#{:erlang.unique_integer([:positive])}")

      link =
        Elixir.Path.join(System.tmp_dir!(), "apero_sym_l_#{:erlang.unique_integer([:positive])}")

      File.write!(target, "content")

      assert :ok = Path.symlink(target, link)
      assert File.read!(link) == "content"

      File.rm!(target)
      File.rm!(link)
    end
  end

  describe "copy/2" do
    test "copies file and creates parent dirs" do
      src =
        Elixir.Path.join(System.tmp_dir!(), "apero_cp_s_#{:erlang.unique_integer([:positive])}")

      dest_dir =
        Elixir.Path.join(System.tmp_dir!(), "apero_cp_d_#{:erlang.unique_integer([:positive])}")

      dest = Elixir.Path.join(dest_dir, "copied.txt")

      File.write!(src, "content")

      assert {:ok, _} = Path.copy(src, dest)
      assert File.read!(dest) == "content"

      File.rm!(src)
      File.rm_rf!(dest_dir)
    end
  end

  describe "move/2" do
    test "moves file" do
      src =
        Elixir.Path.join(System.tmp_dir!(), "apero_mv_s_#{:erlang.unique_integer([:positive])}")

      dest =
        Elixir.Path.join(System.tmp_dir!(), "apero_mv_d_#{:erlang.unique_integer([:positive])}")

      File.write!(src, "content")

      assert :ok = Path.move(src, dest)
      refute File.exists?(src)
      assert File.read!(dest) == "content"

      File.rm!(dest)
    end
  end

  describe "delete/1" do
    test "deletes file and returns :ok even if not exists" do
      path =
        Elixir.Path.join(System.tmp_dir!(), "apero_del_#{:erlang.unique_integer([:positive])}")

      File.write!(path, "content")

      assert :ok = Path.delete(path)
      refute File.exists?(path)

      # Should return :ok even if file doesn't exist
      assert :ok = Path.delete("/nonexistent")
    end
  end

  describe "delete_dir/1" do
    test "deletes directory recursively" do
      dir =
        Elixir.Path.join(System.tmp_dir!(), "apero_del_d_#{:erlang.unique_integer([:positive])}")

      nested = Elixir.Path.join([dir, "a", "b"])
      File.mkdir_p!(nested)
      File.write!(Elixir.Path.join(nested, "file.txt"), "content")

      assert :ok = Path.delete_dir(dir)
      refute File.exists?(dir)
    end
  end

  describe "glob/3" do
    test "lists files matching pattern" do
      dir =
        Elixir.Path.join(System.tmp_dir!(), "apero_glob_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      File.write!(Elixir.Path.join(dir, "file1.txt"), "")
      File.write!(Elixir.Path.join(dir, "file2.txt"), "")
      File.write!(Elixir.Path.join(dir, "other.log"), "")

      files = Path.glob(dir, "*.txt")
      assert length(files) == 2

      File.rm_rf!(dir)
    end
  end

  describe "extension/1" do
    test "returns extension" do
      assert Path.extension("file.tar.gz") == ".gz"
      assert Path.extension("file.txt") == ".txt"
    end
  end

  describe "basename/1" do
    test "returns filename without extension" do
      assert Path.basename("path/to/file.ex") == "file"
    end
  end

  describe "expand/1" do
    test "expands path" do
      assert Path.expand("~/tmp") |> String.contains?("tmp")
    end
  end

  describe "size/1" do
    test "returns file size" do
      path =
        Elixir.Path.join(System.tmp_dir!(), "apero_size_#{:erlang.unique_integer([:positive])}")

      File.write!(path, "hello")

      assert {:ok, 5} = Path.size(path)

      File.rm!(path)
    end
  end

  describe "mtime/1" do
    test "returns modification time" do
      path =
        Elixir.Path.join(System.tmp_dir!(), "apero_mtime_#{:erlang.unique_integer([:positive])}")

      File.write!(path, "content")

      assert {:ok, time} = Path.mtime(path)
      assert %NaiveDateTime{} = time

      File.rm!(path)
    end
  end

  describe "write/2" do
    test "writes content and creates parents" do
      path =
        Elixir.Path.join(
          System.tmp_dir!(),
          "apero_write_#{:erlang.unique_integer([:positive])}/nested/file.txt"
        )

      assert :ok = Path.write(path, "hello")
      assert File.read!(path) == "hello"

      File.rm_rf!(Elixir.Path.dirname(Elixir.Path.dirname(path)))
    end
  end

  describe "read/1" do
    test "reads file content" do
      path =
        Elixir.Path.join(System.tmp_dir!(), "apero_read_#{:erlang.unique_integer([:positive])}")

      File.write!(path, "hello")

      assert {:ok, "hello"} = Path.read(path)

      File.rm!(path)
    end

    test "returns error for non-existent file" do
      assert {:error, _} = Path.read("/nonexistent")
    end
  end

  describe "read_lines/1" do
    test "reads non-empty non-comment lines" do
      path =
        Elixir.Path.join(System.tmp_dir!(), "apero_lines_#{:erlang.unique_integer([:positive])}")

      File.write!(path, "# comment\n\nhello\nworld\n")

      assert {:ok, ["hello", "world"]} = Path.read_lines(path)

      File.rm!(path)
    end
  end
end
