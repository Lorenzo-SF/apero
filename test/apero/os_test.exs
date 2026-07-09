defmodule Apero.OSTest do
  use ExUnit.Case, async: true

  alias Apero.OS

  describe "type/0" do
    test "returns a known atom" do
      assert OS.type() in [:linux, :macos, :windows, :unknown]
    end
  end

  describe "hostname/0" do
    test "returns a non-empty binary" do
      hostname = OS.hostname()
      assert is_binary(hostname)
      assert byte_size(hostname) > 0
    end
  end
end
