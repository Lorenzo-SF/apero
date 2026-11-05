defmodule Apero.ProcTest do
  use ExUnit.Case, async: true

  alias Apero.Proc

  describe "command_exists?/1" do
    test "returns true for commands that exist" do
      assert Proc.command_exists?("ls")
      assert Proc.command_exists?("echo")
    end

    test "returns false for commands that do not exist" do
      refute Proc.command_exists?("this_command_does_not_exist_xyz")
    end

    test "returns false for empty or non-binary input" do
      refute Proc.command_exists?("")
      refute Proc.command_exists?(nil)
      refute Proc.command_exists?(42)
    end
  end

  describe "which/1" do
    test "returns path for existing command" do
      result = Proc.which("ls")
      assert is_binary(result)
      assert String.starts_with?(result, "/")
    end

    test "returns nil for missing command" do
      assert Proc.which("this_cmd_does_not_exist") == nil
    end
  end

  describe "available_commands/1" do
    test "filters to only available commands" do
      result = Proc.available_commands(["ls", "nonexistent_xyz_cmd", "echo"])
      assert "ls" in result
      assert "echo" in result
      refute "nonexistent_xyz_cmd" in result
    end
  end

  describe "locate_commands/1" do
    test "returns map with paths or nil" do
      result = Proc.locate_commands(["ls", "nonexistent_xyz"])
      assert is_map(result)
      assert is_binary(result["ls"])
      assert result["nonexistent_xyz"] == nil
    end
  end

  describe "os_pid/0" do
    test "returns a positive integer" do
      pid = Proc.os_pid()
      assert is_integer(pid)
      assert pid > 0
    end
  end

  describe "scheduler_count/0" do
    test "returns a positive integer" do
      count = Proc.scheduler_count()
      assert is_integer(count)
      assert count >= 1
    end
  end

  describe "vm_memory/0" do
    test "returns a positive integer" do
      mem = Proc.vm_memory()
      assert is_integer(mem)
      assert mem > 0
    end
  end

  describe "vm_uptime/0" do
    test "returns a non-negative integer" do
      uptime = Proc.vm_uptime()
      assert is_integer(uptime)
      assert uptime >= 0
    end
  end
end
