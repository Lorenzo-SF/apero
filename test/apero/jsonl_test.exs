defmodule Apero.JsonlTest do
  use ExUnit.Case, async: true

  alias Apero.Jsonl

  @path Path.join(
          System.tmp_dir(),
          "apero-jsonl-test-#{System.unique_integer([:positive])}.jsonl"
        )

  setup do
    File.rm(@path)
    on_exit(fn -> File.rm(@path) end)
    :ok
  end

  describe "write!/3" do
    test "writes list of maps to JSONL file" do
      maps = [%{"a" => 1}, %{"b" => 2}, %{"c" => 3}]

      assert Jsonl.write!(@path, maps) == :ok
      assert Jsonl.read_all(@path) == {:ok, maps}
    end
  end

  describe "append!/3" do
    test "appends a single map to JSONL file" do
      Jsonl.write!(@path, [%{"a" => 1}, %{"b" => 2}])

      assert Jsonl.append!(@path, %{"c" => 3}) == :ok
      assert Jsonl.read_all(@path) == {:ok, [%{"a" => 1}, %{"b" => 2}, %{"c" => 3}]}
    end

    test "append multiple maps sequentially" do
      Jsonl.write!(@path, [%{"a" => 1}])
      Jsonl.append!(@path, %{"b" => 2})
      Jsonl.append!(@path, %{"c" => 3})

      assert Jsonl.read_all(@path) == {:ok, [%{"a" => 1}, %{"b" => 2}, %{"c" => 3}]}
    end
  end

  describe "stream!/1" do
    test "streams JSONL file as enumerable of maps" do
      maps = [%{"a" => 1}, %{"b" => 2}]
      Jsonl.write!(@path, maps)

      assert Jsonl.stream!(@path) |> Enum.to_list() == maps
    end

    test "skips corrupted lines in the middle" do
      File.write!(@path, "{\"a\": 1}\nnot-json\n{\"b\": 2}\n")

      assert Jsonl.stream!(@path) |> Enum.to_list() == [%{"a" => 1}, %{"b" => 2}]
    end

    test "skips a truncated final line (crash mid-write)" do
      File.write!(@path, "{\"a\": 1}\n{\"b\"")

      assert Jsonl.stream!(@path) |> Enum.to_list() == [%{"a" => 1}]
    end
  end

  describe "read_all/1" do
    test "reads all content from JSONL file" do
      maps = [%{"a" => 1}, %{"b" => 2}]
      Jsonl.write!(@path, maps)

      assert Jsonl.read_all(@path) == {:ok, maps}
    end

    test "returns {:error, :enoent} for missing file" do
      missing =
        Path.join(System.tmp_dir(), "apero-missing-#{System.unique_integer([:positive])}.jsonl")

      assert Jsonl.read_all(missing) == {:error, :enoent}
    end
  end

  describe "recover/2" do
    test "recovers maps from corrupted lines" do
      File.write!(@path, "{\"a\": 1}\ninvalid_json\n{\"b\": 2}\n")

      assert Jsonl.recover(@path, fn line -> Jason.decode(line) end) ==
               [%{"a" => 1}, %{"b" => 2}]
    end

    test "returns [] for a file that is entirely corrupted" do
      File.write!(@path, "garbage\nmore-garbage\n")

      assert Jsonl.recover(@path, fn line -> Jason.decode(line) end) == []
    end
  end
end
