defmodule Apero.FacadeTest do
  use ExUnit.Case, async: true

  describe "Apero facade" do
    test "os_type returns a known atom" do
      assert Apero.os_type() in [:linux, :macos, :windows, :unknown]
    end

    test "os_arch returns an atom" do
      assert Apero.os_arch() in [:x86_64, :arm64, :arm, :i386, :unknown]
    end

    test "sha256 returns a 64-char hex string" do
      assert byte_size(Apero.sha256("hello")) == 64
    end

    test "get_env returns nil for unset variables" do
      assert Apero.get_env("APERO_DEFINITELY_UNSET_VAR_XYZ_12345") == nil
    end
  end
end
