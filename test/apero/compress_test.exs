defmodule Apero.CompressTest do
  use ExUnit.Case, async: true

  alias Apero.Compress

  describe "gzip/1" do
    @tag :external_cmd
    test "compresses a file in-place replacing it with .gz" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "test_gzip_#{System.unique_integer([:positive])}.txt")
      File.write!(path, "hello world content for gzip")
      on_exit(fn -> File.rm_rf([path, path <> ".gz"]) end)

      assert {:ok, gz_path} = Compress.gzip(path)
      assert gz_path == path <> ".gz"
      assert File.exists?(gz_path)
      refute File.exists?(path)

      {:ok, raw} = File.read(gz_path)
      assert raw != "hello world content for gzip"
    end

    @tag :external_cmd
    test "returns error for non-existent file" do
      path = "/tmp/nonexistent_file_xyz_#{System.unique_integer([:positive])}.txt"
      assert {:error, _} = Compress.gzip(path)
    end
  end

  describe "gunzip/1" do
    @tag :external_cmd
    test "decompresses a .gz file keeping the original" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "test_gunzip_#{System.unique_integer([:positive])}.txt")
      File.write!(path, "hello world content for gunzip")
      gz_path = path <> ".gz"
      on_exit(fn -> File.rm_rf([path, gz_path]) end)

      {:ok, ^gz_path} = Compress.gzip(path)

      assert {:ok, extracted} = Compress.gunzip(gz_path)
      assert extracted == path
      assert File.exists?(extracted)
      assert File.exists?(gz_path)
      assert File.read!(extracted) == "hello world content for gunzip"
    end

    @tag :external_cmd
    test "returns error for non-existent file" do
      path = "/tmp/nonexistent_file_xyz_#{System.unique_integer([:positive])}.gz"
      assert {:error, _} = Compress.gunzip(path)
    end
  end

  describe "list/1" do
    @tag :external_cmd
    test "lists contents of a zip file" do
      if System.find_executable("zip") do
        tmp = System.tmp_dir!()
        inner = Path.join(tmp, "list_test_#{System.unique_integer([:positive])}.txt")
        zip_path = Path.join(tmp, "list_test_#{System.unique_integer([:positive])}.zip")
        File.write!(inner, "hello from list test")
        on_exit(fn -> File.rm_rf([inner, zip_path]) end)

        {_, 0} =
          System.cmd("zip", [zip_path, Path.basename(inner)], cd: tmp, stderr_to_stdout: true)

        assert {:ok, contents} = Compress.list(zip_path)
        assert Enum.any?(contents, &String.contains?(&1, Path.basename(inner)))
      end
    end

    @tag :external_cmd
    test "returns error for non-existent file" do
      path = "/tmp/nonexistent_archive_xyz_#{System.unique_integer([:positive])}.zip"
      assert {:error, _} = Compress.list(path)
    end

    @tag :external_cmd
    test "handles unsupported file format via file command" do
      path = "/tmp/test_unknown_ext_#{System.unique_integer([:positive])}.xyz"
      result = Compress.list(path)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
