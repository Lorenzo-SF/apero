defmodule Apero.File.TreeTest do
  use ExUnit.Case, async: true

  alias Apero.File.Tree

  describe "generate_tree/1" do
    test "returns empty string for empty list" do
      assert Tree.generate_tree([]) == ""
    end

    test "returns a binary string, not a map" do
      result = Tree.generate_tree(["a"])
      assert is_binary(result)
    end

    test "last item uses └─" do
      result = Tree.generate_tree(["a"])
      assert result =~ "└─ a"
    end

    test "middle items use ├─" do
      result = Tree.generate_tree(["a", "b"])
      assert result =~ "├─ a"
      assert result =~ "└─ b"
    end
  end

  describe "print_tree/1" do
    test "prints tree to stdout" do
      # Just verify it doesn't crash
      dir =
        Elixir.Path.join(System.tmp_dir!(), "apero_tree_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      File.write!(Elixir.Path.join(dir, "file.txt"), "")

      assert Tree.print_tree(dir) == :ok

      File.rm_rf!(dir)
    end
  end
end
