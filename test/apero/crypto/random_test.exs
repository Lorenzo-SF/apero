defmodule Apero.Crypto.RandomTest do
  use ExUnit.Case, async: true

  alias Apero.Crypto.Random

  describe "generate_key/0" do
    test "returns a 32-byte binary" do
      assert byte_size(Random.generate_key()) == 32
    end

    test "is unique on each call" do
      key1 = Random.generate_key()
      key2 = Random.generate_key()
      assert key1 != key2
    end
  end

  describe "random_hex/1" do
    test "returns string of correct length" do
      assert String.length(Random.random_hex(16)) == 32
    end

    test "is unique on each call" do
      hex1 = Random.random_hex(16)
      hex2 = Random.random_hex(16)
      assert hex1 != hex2
    end

    test "returns hex-encoded string" do
      hex = Random.random_hex(16)
      assert Regex.match?(~r/^[a-f0-9]+$/i, hex)
    end
  end

  describe "random_token/1" do
    test "returns a URL-safe base64 string" do
      token = Random.random_token(32)
      assert is_binary(token)
      # URL-safe base64 doesn't contain +/=
      refute String.contains?(token, "+")
      refute String.contains?(token, "/")
    end

    test "has no padding characters" do
      token = Random.random_token(32)
      refute String.ends_with?(token, "=")
    end
  end

  describe "random_password/2" do
    test "returns string of requested length" do
      assert String.length(Random.random_password(16)) == 16
    end

    test "is unique on each call" do
      pwd1 = Random.random_password(10)
      pwd2 = Random.random_password(10)
      assert pwd1 != pwd2
    end

    test "respects character set options" do
      pwd = Random.random_password(10, upper: false, lower: false, symbols: false)
      # Should only contain digits
      assert Regex.match?(~r/^[0-9]+$/, pwd)
    end

    test "includes symbols when enabled" do
      pwd = Random.random_password(100, symbols: true)
      # Should contain at least one symbol
      assert Regex.match?(~r/[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]/, pwd)
    end
  end

  describe "secure_compare/2" do
    test "equal strings return true" do
      assert Random.secure_compare("hello", "hello") == true
    end

    test "different strings return false" do
      assert Random.secure_compare("hello", "world") == false
    end

    test "different lengths return false" do
      assert Random.secure_compare("short", "longer") == false
    end

    test "non-binaries return false" do
      assert Random.secure_compare("hello", nil) == false
      assert Random.secure_compare(nil, "hello") == false
      assert Random.secure_compare(123, 123) == false
    end
  end
end
