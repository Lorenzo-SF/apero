defmodule Apero.SSHTest do
  use ExUnit.Case, async: true

  alias Apero.SSH

  @moduletag :external_cmd

  describe "function signatures" do
    test "exec/3 is defined" do
      Code.ensure_loaded(SSH)
      assert function_exported?(SSH, :exec, 3)
    end

    test "scp/4 is defined" do
      Code.ensure_loaded(SSH)
      assert function_exported?(SSH, :scp, 4)
    end
  end

  describe "exec/3 — error handling" do
    test "returns error for unreachable host" do
      # Use a TEST-NET address (RFC 5737) that won't resolve
      result =
        SSH.exec("192.0.2.1", "echo hello",
          user: "nobody",
          port: 22,
          identity: "/nonexistent/key"
        )

      assert {:error, {:ssh_failed, _, _}} = result
    end
  end

  describe "scp/4 — error handling" do
    test "returns error for unreachable host" do
      result =
        SSH.scp("/etc/hostname", "192.0.2.1", "/tmp/out",
          user: "nobody",
          port: 22,
          identity: "/nonexistent/key"
        )

      assert {:error, {:scp_failed, _, _}} = result
    end
  end
end
