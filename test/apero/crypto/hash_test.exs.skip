defmodule Apero.Crypto.HashTest do
  use ExUnit.Case, async: true

  alias Apero.Crypto.Hash

  describe "sha256/1" do
    test "returns a 64-char hex string" do
      assert String.length(Hash.sha256("hello")) == 64
    end

    test "is deterministic" do
      assert Hash.sha256("hello") == Hash.sha256("hello")
    end

    test "different inputs produce different hashes" do
      assert Hash.sha256("hello") != Hash.sha256("world")
    end
  end

  describe "sha512/1" do
    test "returns a 128-char hex string" do
      assert String.length(Hash.sha512("hello")) == 128
    end

    test "is deterministic" do
      assert Hash.sha512("hello") == Hash.sha512("hello")
    end
  end

  describe "md5/1" do
    test "returns a 32-char hex string" do
      assert String.length(Hash.md5("hello")) == 32
    end

    test "is deterministic" do
      assert Hash.md5("hello") == Hash.md5("hello")
    end
  end

  describe "hmac/2" do
    test "returns a 64-char hex string" do
      assert String.length(Hash.hmac("secret", "data")) == 64
    end

    test "is deterministic with same inputs" do
      assert Hash.hmac("secret", "data") == Hash.hmac("secret", "data")
    end

    test "different keys produce different results" do
      assert Hash.hmac("key1", "data") != Hash.hmac("key2", "data")
    end
  end
end
