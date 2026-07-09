defmodule Apero.Crypto.KeyTest do
  use ExUnit.Case, async: true

  alias Apero.Crypto.Key

  describe "pbkdf2/3" do
    test "derives a key with default options" do
      derived = Key.pbkdf2("password", "salt")
      assert is_binary(derived)
      assert byte_size(derived) == 32
    end

    test "derives a key with custom length and iterations" do
      derived = Key.pbkdf2("password", "salt", iterations: 10_000, length: 16)
      assert byte_size(derived) == 16
    end

    test "is deterministic" do
      result1 = Key.pbkdf2("password", "salt", iterations: 1000, length: 16)
      result2 = Key.pbkdf2("password", "salt", iterations: 1000, length: 16)
      assert result1 == result2
    end

    test "different salts produce different results" do
      result1 = Key.pbkdf2("password", "salt1", iterations: 1000, length: 16)
      result2 = Key.pbkdf2("password", "salt2", iterations: 1000, length: 16)
      assert result1 != result2
    end
  end

  describe "argon2id/3" do
    test "returns error when argon2_elixir not available" do
      # Argon2 is an optional dependency
      result = Key.argon2id("password", "salt")
      assert result == {:error, :not_available}
    end
  end

  describe "generate_ecdh_keypair/0" do
    test "returns a tuple of two 32-byte binaries" do
      {priv, pub} = Key.generate_ecdh_keypair()
      assert byte_size(priv) == 32
      assert byte_size(pub) == 32
    end

    test "generates unique keypairs" do
      {priv1, pub1} = Key.generate_ecdh_keypair()
      {priv2, pub2} = Key.generate_ecdh_keypair()
      assert priv1 != priv2
      assert pub1 != pub2
    end
  end

  describe "generate_rsa_keypair/0" do
    test "returns ok with private and public DER" do
      assert {:ok, {private_der, public_der}} = Key.generate_rsa_keypair()
      assert is_binary(private_der)
      assert is_binary(public_der)
    end
  end
end
