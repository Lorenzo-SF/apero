defmodule Apero.Cache.Crypto do
  @moduledoc """
  Caching layer for cryptographic operations.

  *Hashes* (`sha256/1`, `sha512/1`, `md5/1`) are expensive due to
  interacting with the `:crypto` Erlang OTP module.  Results are memoised in
  an ETS table with read‑concurrency support.

  Other helpers (`encrypt/2`, `decrypt/2`, random generators) are
  transparently delegated to the real back‑ends (`Apero.Crypto.Hash`,
  `Apero.Crypto.Cipher`, `Apero.Crypto.Random`).  Because those functions
  are already deterministic for a given input we simply wrap them.
  """

  @table :apero_crypto_cache

  @doc """
  Initialise the ETS cache.  The table is created lazily the first time it is
  accessed.
  """
  def init do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _ ->
        :ok
    end
  end

  @doc """
  Memoised SHA‑256.
  """
  def sha256(data) when is_binary(data) do
    init()

    case :ets.lookup(@table, {:sha256, data}) do
      [{_, result}] ->
        result

      [] ->
        result = Apero.Crypto.Hash.sha256(data)
        :ets.insert(@table, {{:sha256, data}, result})
        result
    end
  end

  @doc """
  Memoised SHA‑512.
  """
  def sha512(data) when is_binary(data) do
    init()

    case :ets.lookup(@table, {:sha512, data}) do
      [{_, result}] ->
        result

      [] ->
        result = Apero.Crypto.Hash.sha512(data)
        :ets.insert(@table, {{:sha512, data}, result})
        result
    end
  end

  @doc """
  Memoised MD5.
  """
  def md5(data) when is_binary(data) do
    init()

    case :ets.lookup(@table, {:md5, data}) do
      [{_, result}] ->
        result

      [] ->
        result = Apero.Crypto.Hash.md5(data)
        :ets.insert(@table, {{:md5, data}, result})
        result
    end
  end

  # --- Delegated helpers
  @doc """
  Delegate to cipher encryption.
  """
  def encrypt(plaintext, key \\ nil) do
    Apero.Crypto.Cipher.encrypt(plaintext, key)
  end

  @doc """
  Delegate to cipher decryption.
  """
  def decrypt(ciphertext, key) do
    Apero.Crypto.Cipher.decrypt(ciphertext, key)
  end

  @doc """
  Delegate to random generator.
  """
  def random_hex(byte_count) do
    Apero.Crypto.Random.random_hex(byte_count)
  end

  @doc """
  Delegate to random token generator.
  """
  def random_token(byte_count) do
    Apero.Crypto.Random.random_token(byte_count)
  end

  @doc """
  Delegate to random password generator.
  """
  def random_password(length \\ 24, chars \\ []) do
    Apero.Crypto.Random.random_password(length, chars)
  end
end
