defmodule Apero.CryptoFacadeTest do
  # Tests for the deprecated Apero.Crypto facade (public API coverage)
  use ExUnit.Case, async: true

  alias Apero.Crypto

  describe "hashing facade" do
    test "sha256/1" do
      digest = Crypto.sha256("hello")
      assert String.length(digest) == 64
      assert digest =~ ~r/^[0-9a-f]{64}$/
    end

    test "sha512/1" do
      assert String.length(Crypto.sha512("hello")) == 128
    end

    test "md5/1" do
      assert String.length(Crypto.md5("hello")) == 32
    end

    test "hmac/2" do
      assert String.length(Crypto.hmac("secret", "data")) == 64
    end
  end

  describe "AES-256-GCM facade" do
    test "encrypt/2 + decrypt/2 roundtrip" do
      key = Crypto.generate_key()
      assert {:ok, ct} = Crypto.encrypt("plain", key)
      assert {:ok, "plain"} = Crypto.decrypt(ct, key)
    end
  end

  describe "ChaCha20 facade" do
    test "encrypt_chacha20/2 + decrypt_chacha20/2 roundtrip" do
      key = Crypto.generate_key()
      ct = Crypto.encrypt_chacha20("secret", key)
      assert {:ok, "secret"} = Crypto.decrypt_chacha20(ct, key)
    end
  end

  describe "CTR streaming facade" do
    test "stream_init/encrypt/finalize + decrypt_ctr" do
      key = Crypto.generate_key()
      {state, iv} = Crypto.stream_init(key)
      {state, _, chunk1} = Crypto.stream_encrypt({state, iv}, "hello ")
      {_state, _, chunk2} = Crypto.stream_encrypt({state, iv}, "world")
      ciphertext = chunk1 <> chunk2
      assert {:ok, "hello world"} = Crypto.decrypt_ctr(ciphertext, key, iv)
    end

    test "stream_finalize/1 returns binary" do
      key = Crypto.generate_key()
      {state, _iv} = Crypto.stream_init(key)
      assert is_binary(Crypto.stream_finalize(state))
    end
  end

  describe "ECDH facade" do
    test "generate + compute shared secret" do
      {priv1, pub1} = Crypto.generate_ecdh_keypair()
      {priv2, pub2} = Crypto.generate_ecdh_keypair()
      assert {:ok, s1} = Crypto.compute_ecdh_secret(priv1, pub2)
      assert {:ok, s2} = Crypto.compute_ecdh_secret(priv2, pub1)
      assert s1 == s2
      assert byte_size(s1) == 32
    end
  end

  describe "KDF facade" do
    test "pbkdf2/3 derives a key" do
      derived = Crypto.pbkdf2("password", "salt")
      assert is_binary(derived)
      assert byte_size(derived) == 32
    end
  end

  describe "RSA facade" do
    test "generate_rsa_keypair/0" do
      assert {:ok, {priv_der, pub_der}} = Crypto.generate_rsa_keypair()
      assert is_binary(priv_der)
      assert is_binary(pub_der)
    end
  end

  describe "random facade" do
    test "generate_key/0" do
      assert byte_size(Crypto.generate_key()) == 32
    end

    test "random_hex/1" do
      hex = Crypto.random_hex(16)
      assert String.length(hex) == 32
      assert hex =~ ~r/^[0-9a-f]+$/
    end

    test "random_token/1" do
      token = Crypto.random_token(24)
      assert is_binary(token)
      refute String.contains?(token, "+")
      refute String.contains?(token, "/")
    end

    test "random_password/2" do
      assert String.length(Crypto.random_password(20)) == 20
      assert String.length(Crypto.random_password(12, digits: false)) == 12
    end

    test "secure_compare/2" do
      assert Crypto.secure_compare("abc", "abc")
      refute Crypto.secure_compare("abc", "abd")
      refute Crypto.secure_compare("abc", "abcd")
    end
  end
end
