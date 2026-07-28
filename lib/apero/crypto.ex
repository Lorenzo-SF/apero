defmodule Apero.Crypto do
  # credo:disable-for-this-file Credo.Check.Readability.PreferImplicitTry

  alias Apero.Crypto.{Cipher, Hash, Key, Random}

  alias Apero.Cache.Crypto, as: CacheCrypto

  @moduledoc """
  Cryptographic utilities — hashing, symmetric/asymmetric encryption, KDF.

  ## Submodules

  This module is a facade that delegates to specialized submodules:
    * `Apero.Crypto.Hash` — SHA-256, SHA-512, MD5, HMAC
    * `Apero.Crypto.Cipher` — AES-256-GCM, ChaCha20-Poly1305, AES-256-CTR streaming
    * `Apero.Crypto.Key` — PBKDF2, Argon2id, ECDH, RSA key generation
    * `Apero.Crypto.Random` — key generation, random hex/token/password, secure_compare

  ## Deprecation

  All functions in this module are deprecated in favor of the submodules.
  Use `Apero.Crypto.Hash`, `Apero.Crypto.Cipher`, `Apero.Crypto.Key`, and
  `Apero.Crypto.Random` directly.

  All keys and IVs use `:crypto.strong_rand_bytes/1`. Encrypted values are
  self-contained (IV/nonce + tag + ciphertext, Base64-encoded).
  """

  # ═══════════════════════════════════════════════════════════════════════
  # Hashing (delegated to Apero.Crypto.Hash)
  # ═══════════════════════════════════════════════════════════════════════

  @deprecated "Use Apero.Crypto.Hash.sha256/1 instead"
  @doc "SHA-256 hash (hex encoded)."
  @spec sha256(binary()) :: binary()
  def sha256(data) when is_binary(data), do: CacheCrypto.sha256(data)

  @deprecated "Use Apero.Crypto.Hash.sha512/1 instead"
  @doc "SHA-512 hash (hex encoded)."
  @spec sha512(binary()) :: binary()
  def sha512(data) when is_binary(data), do: CacheCrypto.sha512(data)

  @deprecated "Use Apero.Crypto.Hash.md5/1 instead"
  @doc "MD5 hash (hex encoded). NOTE: MD5 is cryptographically broken — only for checksums."
  @spec md5(binary()) :: binary()
  def md5(data) when is_binary(data), do: CacheCrypto.md5(data)

  @deprecated "Use Apero.Crypto.Hash.hmac/2 instead"
  @doc "HMAC-SHA256 (hex encoded)."
  @spec hmac(binary(), binary()) :: binary()
  def hmac(secret, data) when is_binary(secret) and is_binary(data),
    do: Hash.hmac(secret, data)

  # ═══════════════════════════════════════════════════════════════════════
  # AES-256-GCM (delegated to Apero.Crypto.Cipher)
  # ═══════════════════════════════════════════════════════════════════════

  @deprecated "Use Apero.Crypto.Cipher.encrypt/2 instead"
  @doc "Encrypts plaintext with AES-256-GCM. Returns `{:ok, ciphertext}`."
  @spec encrypt(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def encrypt(plaintext, key) when is_binary(plaintext) and byte_size(key) == 32 do
    Cipher.encrypt(plaintext, key)
  end

  @deprecated "Use Apero.Crypto.Cipher.decrypt/2 instead"
  @doc "Decrypts a value encrypted with `encrypt/2`. Returns `{:ok, plaintext}` or `{:error, reason}`."
  @spec decrypt(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def decrypt(encoded, key) when is_binary(encoded) and byte_size(key) == 32,
    do: Cipher.decrypt(encoded, key)

  # ═══════════════════════════════════════════════════════════════════════
  # ChaCha20-Poly1305 (delegated to Apero.Crypto.Cipher)
  # ═══════════════════════════════════════════════════════════════════════

  @deprecated "Use Apero.Crypto.Cipher.encrypt_chacha20/2 instead"
  @doc "Encrypts plaintext with ChaCha20-Poly1305."
  @spec encrypt_chacha20(binary(), binary()) :: binary()
  def encrypt_chacha20(plaintext, key) when is_binary(plaintext) and byte_size(key) == 32,
    do: Cipher.encrypt_chacha20(plaintext, key)

  @deprecated "Use Apero.Crypto.Cipher.decrypt_chacha20/2 instead"
  @doc "Decrypts ChaCha20-Poly1305 encrypted data."
  @spec decrypt_chacha20(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def decrypt_chacha20(encoded, key) when is_binary(encoded) and byte_size(key) == 32,
    do: Cipher.decrypt_chacha20(encoded, key)

  # ═══════════════════════════════════════════════════════════════════════
  # AES-256-CTR (delegated to Apero.Crypto.Cipher)
  # ═══════════════════════════════════════════════════════════════════════

  @dialyzer {:nowarn_function, stream_init: 1}
  @dialyzer {:nowarn_function, stream_encrypt: 2}
  @dialyzer {:nowarn_function, stream_finalize: 1}

  @deprecated "Use Apero.Crypto.Cipher.stream_init/1 instead"
  @doc "Starts an AES-256-CTR encryption stream. Use with `stream_encrypt/2` and `stream_finalize/1`."
  @spec stream_init(binary()) :: {any(), binary()}
  def stream_init(key) when byte_size(key) == 32,
    do: Cipher.stream_init(key)

  @deprecated "Use Apero.Crypto.Cipher.stream_encrypt/2 instead"
  @doc "Encrypts a chunk of data in streaming mode."
  @spec stream_encrypt({any(), binary()}, binary()) :: {any(), binary(), binary()}
  def stream_encrypt({state, iv}, chunk),
    do: Cipher.stream_encrypt({state, iv}, chunk)

  @deprecated "Use Apero.Crypto.Cipher.stream_finalize/1 instead"
  @doc "Finalizes a streaming encryption. Returns the final state (discard after)."
  @spec stream_finalize(any()) :: binary()
  def stream_finalize(state),
    do: Cipher.stream_finalize(state)

  @dialyzer {:nowarn_function, decrypt_ctr: 3}

  @deprecated "Use Apero.Crypto.Cipher.decrypt_ctr/3 instead"
  @doc "Decrypts data encrypted with AES-256-CTR streaming."
  @spec decrypt_ctr(binary(), binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def decrypt_ctr(ciphertext, key, iv) when byte_size(key) == 32 and byte_size(iv) == 16,
    do: Cipher.decrypt_ctr(ciphertext, key, iv)

  # ═══════════════════════════════════════════════════════════════════════
  # ECDH (delegated to Apero.Crypto.Key)
  # ═══════════════════════════════════════════════════════════════════════

  @deprecated "Use Apero.Crypto.Key.generate_ecdh_keypair/0 instead"
  @doc "Generates an X25519 key pair. Returns `{private_key, public_key}` (both raw binary)."
  @spec generate_ecdh_keypair() :: {binary(), binary()}
  def generate_ecdh_keypair,
    do: Key.generate_ecdh_keypair()

  @deprecated "Use Apero.Crypto.Key.compute_ecdh_secret/2 instead"
  @doc "Computes a shared secret from your private key and peer's public key."
  @spec compute_ecdh_secret(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def compute_ecdh_secret(my_private, peer_public),
    do: Key.compute_ecdh_secret(my_private, peer_public)

  # ═══════════════════════════════════════════════════════════════════════
  # Key derivation (delegated to Apero.Crypto.Key)
  # ═══════════════════════════════════════════════════════════════════════

  @dialyzer {:nowarn_function, {:pbkdf2, 2}}
  @dialyzer {:nowarn_function, {:pbkdf2, 3}}

  @deprecated "Use Apero.Crypto.Key.pbkdf2/3 instead"
  @doc "Derives a key using PBKDF2-HMAC-SHA256."
  @spec pbkdf2(binary(), binary(), keyword()) :: binary()
  def pbkdf2(password, salt, opts \\ []) when is_binary(password) and is_binary(salt),
    do: Key.pbkdf2(password, salt, opts)

  @deprecated "Use Apero.Crypto.Key.argon2id/3 instead"
  @doc "Derives a key using Argon2id (requires optional `argon2_elixir` dependency)."
  @spec argon2id(binary(), binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def argon2id(password, salt, opts \\ []),
    do: Key.argon2id(password, salt, opts)

  # ═══════════════════════════════════════════════════════════════════════
  # RSA (delegated to Apero.Crypto.Key)
  # ═══════════════════════════════════════════════════════════════════════

  @deprecated "Use Apero.Crypto.Key.generate_rsa_keypair/0 instead"
  @doc "Generates an RSA key pair (2048-bit). Returns `{private_der, public_der}`."
  @spec generate_rsa_keypair() :: {:ok, {binary(), binary()}} | {:error, term()}
  def generate_rsa_keypair,
    do: Key.generate_rsa_keypair()

  # ═══════════════════════════════════════════════════════════════════════
  # Random generation (delegated to Apero.Crypto.Random)
  # ═══════════════════════════════════════════════════════════════════════

  @deprecated "Use Apero.Crypto.Random.generate_key/0 instead"
  @doc "Generates a random 256-bit key."
  @spec generate_key() :: binary()
  def generate_key,
    do: Random.generate_key()

  @deprecated "Use Apero.Crypto.Random.random_hex/1 instead"
  @doc "Generates a random hex string."
  @spec random_hex(non_neg_integer()) :: binary()
  def random_hex(bytes \\ 32),
    do: Random.random_hex(bytes)

  @deprecated "Use Apero.Crypto.Random.random_token/1 instead"
  @doc "Generates a random URL-safe token."
  @spec random_token(non_neg_integer()) :: binary()
  def random_token(bytes \\ 32),
    do: Random.random_token(bytes)

  @deprecated "Use Apero.Crypto.Random.random_password/2 instead"
  @doc "Generates a random password with configurable length and character sets."
  @spec random_password(non_neg_integer(), keyword()) :: binary()
  def random_password(length \\ 24, opts \\ []),
    do: Random.random_password(length, opts)

  @deprecated "Use Apero.Crypto.Random.secure_compare/2 instead"
  @doc "Timing-safe string comparison."
  @spec secure_compare(binary(), binary()) :: boolean()
  def secure_compare(a, b) when is_binary(a) and is_binary(b) and byte_size(a) == byte_size(b),
    do: Random.secure_compare(a, b)

  def secure_compare(_, _), do: false
end
