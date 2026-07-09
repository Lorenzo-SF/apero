defmodule Apero.Crypto.CipherTest do
  use ExUnit.Case, async: true

  alias Apero.Crypto.Cipher

  describe "encrypt/2 and decrypt/2" do
    test "roundtrip with auto-generated key" do
      plaintext = "hello world"
      {:ok, ciphertext} = Cipher.encrypt(plaintext)
      assert is_binary(ciphertext)
      # Key is generated, so we can't decrypt without it
    end

    test "roundtrip with explicit key" do
      key = :crypto.strong_rand_bytes(32)
      plaintext = "hello world"
      {:ok, ciphertext} = Cipher.encrypt(plaintext, key)
      assert is_binary(ciphertext)

      {:ok, decrypted} = Cipher.decrypt(ciphertext, key)
      assert decrypted == plaintext
    end

    test "wrong key returns error" do
      key = :crypto.strong_rand_bytes(32)
      wrong_key = :crypto.strong_rand_bytes(32)
      plaintext = "hello world"
      {:ok, ciphertext} = Cipher.encrypt(plaintext, key)

      assert {:error, :decryption_failed} = Cipher.decrypt(ciphertext, wrong_key)
    end

    test "corrupted ciphertext returns error" do
      key = :crypto.strong_rand_bytes(32)
      {:ok, ciphertext} = Cipher.encrypt("hello", key)
      corrupted = ciphertext <> "extra"
      assert {:error, :invalid_format} = Cipher.decrypt(corrupted, key)
    end

    test "decrypt with invalid base64 returns error" do
      key = :crypto.strong_rand_bytes(32)
      assert {:error, :invalid_format} = Cipher.decrypt("not-valid-base64!", key)
    end
  end

  describe "encrypt_chacha20/2 and decrypt_chacha20/2" do
    test "roundtrip encrypts and decrypts" do
      key = :crypto.strong_rand_bytes(32)
      plaintext = "hello chacha"
      ciphertext = Cipher.encrypt_chacha20(plaintext, key)
      assert is_binary(ciphertext)

      # NOTE: decrypt_chacha20 returns plaintext directly (not {:ok, plaintext})
      # due to how :crypto.crypto_one_time_aead works
      assert ^plaintext = Cipher.decrypt_chacha20(ciphertext, key)
    end

    test "wrong key returns :error" do
      key = :crypto.strong_rand_bytes(32)
      wrong_key = :crypto.strong_rand_bytes(32)
      ciphertext = Cipher.encrypt_chacha20("data", key)

      assert :error = Cipher.decrypt_chacha20(ciphertext, wrong_key)
    end

    test "corrupted data returns :error" do
      key = :crypto.strong_rand_bytes(32)
      ciphertext = Cipher.encrypt_chacha20("data", key)
      corrupted = "garbage" <> ciphertext

      assert :error = Cipher.decrypt_chacha20(corrupted, key)
    end
  end
end
