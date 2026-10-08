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

  describe "distro/0" do
    test "returns a non-empty binary" do
      distro = OS.distro()
      assert is_binary(distro)
      assert byte_size(distro) > 0
    end

    test "matches platform" do
      case OS.type() do
        :macos -> assert OS.distro() == "macOS"
        :windows -> assert OS.distro() == "Windows"
        :linux -> assert OS.distro() =~ ~r/(Linux|Ubuntu|Fedora|Arch|Debian|Cachy|Manjaro|NixOS|openSUSE|CentOS|Red Hat|Alma|Rocky|Mint|elementary)/
        _ -> assert OS.distro() == "unknown"
      end
    end
  end

  describe "wsl?/0" do
    test "returns a boolean" do
      assert is_boolean(OS.wsl?())
    end

    test "is false on non-linux platforms" do
      if OS.type() != :linux do
        refute OS.wsl?()
      end
    end
  end

  describe "container?/0" do
    test "returns a boolean" do
      assert is_boolean(OS.container?())
    end
  end
end
