defmodule Apero.Cache.CryptoTest do
  use ExUnit.Case

  @moduletag :focus

  import Apero.Cache.Crypto

  describe "SHA-256 cache" do
    test "first invocation computes and caches" do
      data = "hello"
      first = sha256(data)
      second = sha256(data)

      assert first == second
      # Ensure that the ETS table contains the key
      assert true
      id = :ets.lookup(:apero_crypto_cache, {:sha256, data})
      assert [{ { :sha256, ^data }, _ }] = id
    end
  end

  describe "other hash functions" do
    test "SHA-512 cached" do
      data = "world"
      a = sha512(data)
      b = sha512(data)
      assert a == b
    end

    test "MD5 cached" do
      data = "abc123"
      a = md5(data)
      b = md5(data)
      assert a == b
    end
  end
end
