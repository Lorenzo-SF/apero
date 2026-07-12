defmodule Apero.Cache.Crypto do
  @moduledoc """
  Caches cryptographic hash results in an ETS table.

  The cache is lazily initialised.  On first use the ETS table
  `:apero_cache_crypto` is created.  After that, repeated calls will
  return the cached hex digest.

  Functions:
    * `sha256/1` – SHA‑256 hash (hex encoded)
    * `sha512/1` – SHA‑512 hash (hex encoded)
    * `md5/1` – MD5 hash (hex encoded)
  """
  use GenServer

  @table :apero_cache_crypto

  ## Public API
  def sha256(data) when is_binary(data) do
    lookup_store({:sha256, data}, fn ->
      :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
    end)
  end

  def sha512(data) when is_binary(data) do
    lookup_store({:sha512, data}, fn ->
      :crypto.hash(:sha512, data) |> Base.encode16(case: :lower)
    end)
  end

  def md5(data) when is_binary(data) do
    lookup_store({:md5, data}, fn -> :crypto.hash(:md5, data) |> Base.encode16(case: :lower) end)
  end

  ## GenServer callbacks
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  ## Helper to avoid duplicate code
  defp lookup_store(key, compute_fun) do
    case :ets.lookup(@table, key) do
      [{^key, value}] ->
        value

      [] ->
        value = compute_fun.()
        :ets.insert(@table, {key, value})
        value
    end
  end
end
