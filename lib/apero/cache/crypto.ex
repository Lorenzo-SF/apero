defmodule Apero.Cache.Crypto do
  @moduledoc """
  Caches cryptographic hash results in an ETS table.

  The ETS table `:apero_cache_crypto` is created at application startup.
  After that, repeated calls will return the cached hex digest.

  Functions:
    * `sha256/1` – SHA‑256 hash (hex encoded)
    * `sha512/1` – SHA‑512 hash (hex encoded)
    * `md5/1` – MD5 hash (hex encoded)
  """

  @table :apero_cache_crypto

  @doc false
  def init_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _ ->
        :ok
    end
  end

  ## Public API

  @doc "SHA-256 hash (hex encoded)."
  @spec sha256(binary()) :: binary()
  def sha256(data) when is_binary(data) do
    lookup_store({:sha256, data}, fn ->
      :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
    end)
  end

  @doc "SHA-512 hash (hex encoded)."
  @spec sha512(binary()) :: binary()
  def sha512(data) when is_binary(data) do
    lookup_store({:sha512, data}, fn ->
      :crypto.hash(:sha512, data) |> Base.encode16(case: :lower)
    end)
  end

  @doc "MD5 hash (hex encoded). NOTE: MD5 is cryptographically broken — only for checksums."
  @spec md5(binary()) :: binary()
  def md5(data) when is_binary(data) do
    lookup_store({:md5, data}, fn -> :crypto.hash(:md5, data) |> Base.encode16(case: :lower) end)
  end

  ## Helpers

  defp lookup_store(key, compute_fun) do
    value = compute_fun.()

    case :ets.insert_new(@table, {key, value}) do
      true -> value
      false -> :ets.lookup_element(@table, key, 2)
    end
  end
end
