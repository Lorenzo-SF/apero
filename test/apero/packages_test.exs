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

  describe "available_managers/0" do
    test "returns a list of atoms" do
      managers = Packages.available_managers()
      assert is_list(managers)
      Enum.each(managers, fn mgr -> assert is_atom(mgr) end)
    end

    test "agrees with detect/0 keys" do
      assert Packages.available_managers() |> Enum.sort() ==
               Packages.detect() |> Map.keys() |> Enum.sort()
    end
  end

  describe "path_for/1" do
    test "returns nil for missing manager" do
      assert Packages.path_for(:nonexistent_manager_xyz) == nil
    end

    test "returns binary path or nil for known manager" do
      result = Packages.path_for(:brew)
      assert result == nil or is_binary(result)
    end
  end
end
