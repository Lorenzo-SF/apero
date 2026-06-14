defmodule Apero.Crypto.Key do
  @moduledoc """
  Key derivation and asymmetric key generation utilities.

  Provides:
    * Key derivation: PBKDF2, Argon2id
    * Key exchange: ECDH (X25519)
    * Asymmetric: RSA key generation
  """

  # ═══════════════════════════════════════════════════════════════════════
  # Key derivation (KDF)
  # ═══════════════════════════════════════════════════════════════════════

  @dialyzer {:nowarn_function, {:pbkdf2, 2}}
  @dialyzer {:nowarn_function, {:pbkdf2, 3}}

  @doc "Derives a key using PBKDF2-HMAC-SHA256."
  @spec pbkdf2(binary(), binary(), keyword()) :: binary()
  def pbkdf2(password, salt, opts \\ []) when is_binary(password) and is_binary(salt) do
    iterations = Keyword.get(opts, :iterations, 100_000)
    length = Keyword.get(opts, :length, 32)

    if function_exported?(:crypto, :pbkdf2_hmac, 5) do
      IO.iodata_to_binary(:crypto.pbkdf2_hmac(:sha256, password, salt, iterations, length))
    else
      IO.iodata_to_binary(:crypto.pbkdf2_hmac(password, salt, iterations, length, :sha256))
    end
  end

  @doc "Derives a key using Argon2id (requires optional `argon2_elixir` dependency)."
  @spec argon2id(binary(), binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def argon2id(password, salt, opts \\ []) do
    if Code.ensure_loaded?(Argon2) do
      t_cost = Keyword.get(opts, :t_cost, 2)
      m_cost = Keyword.get(opts, :m_cost, 65_536)

      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(Argon2, :hash_passwd, [password, [salt: salt, t_cost: t_cost, m_cost: m_cost]])
    else
      {:error, :not_available}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ECDH (X25519 key exchange)
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Generates an X25519 key pair. Returns `{private_key, public_key}` (both raw binary)."
  @spec generate_ecdh_keypair() :: {binary(), binary()}
  def generate_ecdh_keypair do
    private = :crypto.strong_rand_bytes(32)
    public = :crypto.generate_key(:ecdh, :x25519, private) |> elem(1)
    {private, public}
  end

  @doc "Computes a shared secret from your private key and peer's public key."
  @spec compute_ecdh_secret(binary(), binary()) :: {:ok, binary()} | :error
  def compute_ecdh_secret(my_private, peer_public)
      when byte_size(my_private) == 32 and byte_size(peer_public) == 32 do
    try do
      {:ok, :crypto.compute_key(:ecdh, peer_public, my_private, :x25519)}
    rescue
      _ -> :error
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RSA
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Generates an RSA key pair (2048-bit). Returns `{private_der, public_der}`."
  @spec generate_rsa_keypair() :: {:ok, {binary(), binary()}} | {:error, term()}
  def generate_rsa_keypair do
    try do
      key = :public_key.generate_key({:rsa, 2048, 65_537})
      private_der = :public_key.der_encode(:RSAPrivateKey, key)

      public_key = {:RSAPublicKey, :erlang.element(3, key), :erlang.element(4, key)}
      public_der = :public_key.der_encode(:RSAPublicKey, public_key)

      {:ok, {private_der, public_der}}
    rescue
      e -> {:error, e}
    end
  end
end
