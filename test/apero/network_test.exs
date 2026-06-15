defmodule Apero.NetworkTest do
  use ExUnit.Case, async: true

  alias Apero.Network

  @moduletag :external_cmd

  describe "ping/2" do
    @tag :external_cmd
    test "returns :ok when host responds" do
      # localhost should respond to ping on CI/dev machines
      assert Network.ping("127.0.0.1", count: 1, timeout: 2_000) == :ok
    end
  end

  describe "resolve/1" do
    test "resolves localhost" do
      assert {:ok, addresses} = Network.resolve("localhost")
      assert is_list(addresses)
      assert addresses != []
    end

    test "returns error for invalid hostname" do
      assert {:error, _} = Network.resolve("this-host-does-not-exist-12345.invalid")
    end
  end

  describe "port_open?/3" do
    test "returns true for an open port" do
      # Port 7 (echo) or any commonly-open port
      {:ok, server} = :gen_tcp.listen(0, active: false)
      {:ok, port} = :inet.port(server)
      assert Network.port_open?("127.0.0.1", port, timeout: 1_000)
      :gen_tcp.close(server)
    end

    test "returns false for a closed port" do
      # 1 is unlikely to be open
      refute Network.port_open?("127.0.0.1", 1, timeout: 500)
    end
  end

  describe "scan_ports/3" do
    test "returns map of port status" do
      {:ok, server} = :gen_tcp.listen(0, active: false)
      {:ok, port} = :inet.port(server)
      result = Network.scan_ports("127.0.0.1", [port, 1], timeout: 1_000)
      assert result == %{port => :open, 1 => :closed}
      :gen_tcp.close(server)
    end
  end
end
