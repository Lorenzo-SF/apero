defmodule Apero.FacadeTest do
  use ExUnit.Case, async: true

  describe "Apero facade" do
    test "os_type returns a known atom" do
      assert Apero.os_type() in [:linux, :macos, :windows, :unknown]
    end

    test "os_arch returns an atom" do
      assert Apero.os_arch() in [:x86_64, :arm64, :arm, :i386, :unknown]
    end
  end
end
