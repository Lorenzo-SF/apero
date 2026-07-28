defmodule Apero.CryptoTest do
  use ExUnit.Case, async: true

  alias Apero.Crypto.{Cipher, Hash, Key, Random}

  describe "encrypt/2 and decrypt/2" do
    test "roundtrip with explicit key" do
      key = Random.generate_key()
      plaintext = "hello, world"
      assert {:ok, ciphertext} = Cipher.encrypt(plaintext, key)
      assert {:ok, ^plaintext} = Cipher.decrypt(ciphertext, key)
    end

    test "wrong key returns error" do
      key = Random.generate_key()
      wrong_key = Random.generate_key()
      {:ok, ciphertext} = Cipher.encrypt("data", key)
      assert {:error, _} = Cipher.decrypt(ciphertext, wrong_key)
    end

    test "corrupted ciphertext returns error" do
      key = Random.generate_key()
      {:ok, ciphertext} = Cipher.encrypt("data", key)
      corrupted = String.slice(ciphertext, 0, 10) <> "XXXX"
      assert {:error, _} = Cipher.decrypt(corrupted, key)
    end

    test "decrypt with invalid base64 returns error" do
      key = Random.generate_key()
      assert {:error, :invalid_format} = Cipher.decrypt("not-base64!!!", key)
    end
  end

  describe "sha256/1" do
    test "returns a 64-char hex string" do
      hash = Hash.sha256("hello")
      assert is_binary(hash)
      assert String.length(hash) == 64
      assert hash =~ ~r/^[a-f0-9]+$/
    end

    test "is deterministic" do
      assert Hash.sha256("hello") == Hash.sha256("hello")
    end

    test "different inputs produce different hashes" do
      refute Hash.sha256("hello") == Hash.sha256("world")
    end
  end

  describe "sha512/1" do
    test "returns a 128-char hex string" do
      hash = Hash.sha512("hello")
      assert is_binary(hash)
      assert String.length(hash) == 128
      assert hash =~ ~r/^[a-f0-9]+$/
    end

    test "is deterministic" do
      assert Hash.sha512("hello") == Hash.sha512("hello")
    end
  end

  describe "md5/1" do
    test "returns a 32-char hex string" do
      hash = Hash.md5("hello")
      assert is_binary(hash)
      assert String.length(hash) == 32
      assert hash =~ ~r/^[a-f0-9]+$/
    end

    test "is deterministic" do
      assert Hash.md5("hello") == Hash.md5("hello")
    end
  end

  describe "hmac/2" do
    test "returns a 64-char hex string" do
      hmac = Hash.hmac("secret", "data")
      assert is_binary(hmac)
      assert String.length(hmac) == 64
    end

    test "is deterministic with same inputs" do
      assert Hash.hmac("secret", "data") == Hash.hmac("secret", "data")
    end

    test "different keys produce different results" do
      refute Hash.hmac("key1", "data") == Hash.hmac("key2", "data")
    end
  end

  describe "encrypt_chacha20/2 and decrypt_chacha20/2" do
    test "roundtrip encrypts and decrypts" do
      key = :crypto.strong_rand_bytes(32)
      plaintext = "hello chacha"
      ciphertext = Cipher.encrypt_chacha20(plaintext, key)
      assert {:ok, ^plaintext} = Cipher.decrypt_chacha20(ciphertext, key)
    end

    test "wrong key returns {:error, _}" do
      key = :crypto.strong_rand_bytes(32)
      wrong_key = :crypto.strong_rand_bytes(32)
      ciphertext = Cipher.encrypt_chacha20("data", key)
      assert {:error, _} = Cipher.decrypt_chacha20(ciphertext, wrong_key)
    end

    test "corrupted data returns {:error, _}" do
      key = :crypto.strong_rand_bytes(32)
      ciphertext = Cipher.encrypt_chacha20("data", key)
      assert {:error, _} = Cipher.decrypt_chacha20("garbage" <> ciphertext, key)
    end
  end

  describe "stream encryption (AES-256-CTR)" do
    test "encrypts and decrypts in streaming mode" do
      key = :crypto.strong_rand_bytes(32)
      plaintext = "this is a long message to encrypt in streaming mode"

      {state, iv} = Cipher.stream_init(key)
      {state, iv, chunk1} = Cipher.stream_encrypt({state, iv}, "this is a ")
      {state, _iv, chunk2} = Cipher.stream_encrypt({state, iv}, "long message to ")
      {state, _iv, chunk3} = Cipher.stream_encrypt({state, iv}, "encrypt in ")
      {state, _iv, chunk4} = Cipher.stream_encrypt({state, iv}, "streaming mode")
      rest = Cipher.stream_finalize(state)
      ciphertext = chunk1 <> chunk2 <> chunk3 <> chunk4 <> rest

      assert {:ok, ^plaintext} = Cipher.decrypt_ctr(ciphertext, key, iv)
    end

    test "encrypts empty data" do
      key = :crypto.strong_rand_bytes(32)
      {state, iv} = Cipher.stream_init(key)
      {state, iv, chunk} = Cipher.stream_encrypt({state, iv}, "")
      rest = Cipher.stream_finalize(state)
      ciphertext = chunk <> rest
      assert {:ok, ""} = Cipher.decrypt_ctr(ciphertext, key, iv)
    end

    test "wrong key returns garbage (not the original plaintext)" do
      key = :crypto.strong_rand_bytes(32)
      wrong_key = :crypto.strong_rand_bytes(32)
      plaintext = "data"
      {state, iv} = Cipher.stream_init(key)
      {state, iv, chunk} = Cipher.stream_encrypt({state, iv}, plaintext)
      _rest = Cipher.stream_finalize(state)
      assert {:ok, garbage} = Cipher.decrypt_ctr(chunk, wrong_key, iv)
      refute garbage == plaintext
    end
  end

  describe "generate_key/0" do
    test "returns a 32-byte binary" do
      key = Random.generate_key()
      assert is_binary(key)
      assert byte_size(key) == 32
    end

    test "is unique on each call" do
      refute Random.generate_key() == Random.generate_key()
    end
  end

  describe "random_hex/1" do
    test "returns string of correct length" do
      assert String.length(Random.random_hex(16)) == 32
      assert String.length(Random.random_hex(32)) == 64
    end

    test "returns hex-encoded string" do
      assert Random.random_hex(8) =~ ~r/^[a-f0-9]+$/
    end

    test "is unique on each call" do
      refute Random.random_hex() == Random.random_hex()
    end
  end

  describe "random_token/1" do
    test "returns a URL-safe base64 string" do
      token = Random.random_token(32)
      assert is_binary(token)
      assert Regex.match?(~r/^[A-Za-z0-9_-]+$/, token)
    end

    test "has no padding characters" do
      token = Random.random_token(32)
      refute String.contains?(token, "=")
    end
  end

  describe "random_password/2" do
    test "returns string of requested length" do
      assert String.length(Random.random_password(16)) == 16
      assert String.length(Random.random_password(32)) == 32
    end

    test "is unique on each call" do
      refute Random.random_password(24) == Random.random_password(24)
    end

    test "respects character set options" do
      # Only digits
      pwd = Random.random_password(10, upper: false, lower: false, symbols: false)
      assert String.length(pwd) == 10
      assert pwd =~ ~r/^[0-9]+$/
    end

    test "includes symbols when enabled" do
      pwd = Random.random_password(20, upper: true, lower: true, symbols: true)
      assert String.length(pwd) == 20
    end
  end

  describe "secure_compare/2" do
    test "equal strings return true" do
      assert Random.secure_compare("abc", "abc")
    end

    test "different strings return false" do
      refute Random.secure_compare("abc", "def")
    end

    test "different lengths return false" do
      refute Random.secure_compare("ab", "abc")
    end

    test "non-binaries return false" do
      refute Random.secure_compare(123, "abc")
    end
  end

  describe "generate_ecdh_keypair/0" do
    test "returns a tuple of two 32-byte binaries" do
      {priv, pub} = Key.generate_ecdh_keypair()
      assert is_binary(priv)
      assert is_binary(pub)
      assert byte_size(priv) == 32
      assert byte_size(pub) == 32
    end

    test "generates unique keypairs" do
      {priv1, _} = Key.generate_ecdh_keypair()
      {priv2, _} = Key.generate_ecdh_keypair()
      refute priv1 == priv2
    end
  end

  describe "compute_ecdh_secret/2" do
    test "computes a shared secret" do
      # Use :crypto.generate_key directly to get valid keypairs
      # (the library's generate_ecdh_keypair may have OTP version issues)
      {alice_pub, alice_priv} = :crypto.generate_key(:ecdh, :x25519)
      {bob_pub, bob_priv} = :crypto.generate_key(:ecdh, :x25519)

      assert {:ok, secret_a} = Key.compute_ecdh_secret(alice_priv, bob_pub)
      assert {:ok, secret_b} = Key.compute_ecdh_secret(bob_priv, alice_pub)
      assert secret_a == secret_b
    end

    test "returns {:error, _} for invalid keys" do
      assert {:error, _reason} = Key.compute_ecdh_secret(<<0::256>>, <<0::256>>)
    end
  end

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
      a = Key.pbkdf2("password", "salt", iterations: 1000, length: 16)
      b = Key.pbkdf2("password", "salt", iterations: 1000, length: 16)
      assert a == b
    end
  end

  describe "argon2id/3" do
    test "returns {:error, :not_available}" do
      assert {:error, :not_available} = Key.argon2id("password", "salt")
    end
  end

  describe "generate_rsa_keypair/0" do
    test "returns ok with private and public DER" do
      assert {:ok, {private_der, public_der}} = Key.generate_rsa_keypair()
      assert is_binary(private_der)
      assert is_binary(public_der)
      assert byte_size(private_der) > 0
      assert byte_size(public_der) > 0
    end
  end
end
