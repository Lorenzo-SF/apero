defmodule Apero.PackagesTest do
  use ExUnit.Case, async: true

  alias Apero.Packages

  describe "detect/0" do
    test "returns a map of detected managers" do
      detected = Packages.detect()
      assert is_map(detected)
      # Every value is a binary path
      Enum.each(detected, fn {_mgr, path} -> assert is_binary(path) end)
    end

    test "keys are known managers" do
      known = [
        :apt,
        :apt_get,
        :brew,
        :pacman,
        :yum,
        :dnf,
        :apk,
        :zypper,
        :pkg,
        :winget,
        :choco,
        :port,
        :nix
      ]

      Enum.each(Packages.detect(), fn {mgr, _} -> assert mgr in known end)
    end
  end

  describe "preferred/0" do
    test "returns a manager or nil" do
      result = Packages.preferred()
      assert result == nil or is_atom(result)
    end
  end

  describe "available?/1" do
    test "works for any known manager atom" do
      assert is_boolean(Packages.available?(:brew))
      assert is_boolean(Packages.available?(:apt))
      assert is_boolean(Packages.available?(:pacman))
    end
  end
end
