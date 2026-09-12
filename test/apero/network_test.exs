defmodule Apero.NetworkTest do
  use ExUnit.Case, async: true

  alias Apero.Network

  describe "resolve/1" do
    test "resolves localhost to an IP" do
      assert {:ok, ips} = Network.resolve("localhost")
      assert is_list(ips)
      assert ips != []
      Enum.each(ips, fn ip -> assert is_binary(ip) end)
    end

    test "resolves a known domain" do
      assert {:ok, ips} = Network.resolve("example.com")
      assert ips != []
    end

    test "returns error for invalid host" do
      assert {:error, _} = Network.resolve("this-host-does-not-exist-abc123.invalid")
    end
  end
end
