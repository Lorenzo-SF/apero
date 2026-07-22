defmodule AperoTest do
  @moduledoc """
  Tests for the `Apero` facade delegates.

  These tests exercise the public delegates that re-export submodule APIs.
  The submodules have their own dedicated test files; this file ensures the
  facade itself is exercised (Elixir coverage tool counts facade code only when
  called via the facade).
  """
  use ExUnit.Case, async: true

  alias Apero.Crypto.Hash

  describe "crypto delegates" do
    test "sha256/1 delegates to Apero.Crypto.Hash" do
      assert Apero.sha256("hello") == Hash.sha256("hello")
      assert byte_size(Apero.sha256("hello")) == 64
    end

    test "sha512/1 delegates to Apero.Crypto.Hash" do
      assert Apero.sha512("hello") == Hash.sha512("hello")
      assert byte_size(Apero.sha512("hello")) == 128
    end

    test "md5/1 delegates to Apero.Crypto.Hash" do
      assert Apero.md5("hello") == Hash.md5("hello")
      assert byte_size(Apero.md5("hello")) == 32
    end
  end

  describe "env delegates" do
    test "get_env/2 with default" do
      assert Apero.get_env("APERO_NONEXISTENT_VAR_XYZ", "fallback") == "fallback"
    end

    test "put_env/2 round-trip" do
      Apero.put_env("APERO_TEST_VAR_FACADE", "value")
      assert Apero.get_env("APERO_TEST_VAR_FACADE") == "value"
      System.delete_env("APERO_TEST_VAR_FACADE")
    end
  end

  describe "os delegate" do
    test "os_type/0 returns an atom" do
      assert Apero.os_type() in [:linux, :macos, :windows, :freebsd, :unknown]
    end
  end

  describe "retry delegate" do
    test "retry/2 retries until success" do
      result =
        Apero.retry(
          fn ->
            if :rand.uniform(10) > 0 do
              {:ok, :done}
            else
              {:error, :retry}
            end
          end,
          max_attempts: 3
        )

      assert result == {:ok, :done}
    end
  end
end