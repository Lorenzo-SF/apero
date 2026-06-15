defmodule Apero.Cache do
  @moduledoc """
  Unified cache interface — ETS, Redis, Memcached.

  Provides a consistent API for different cache backends via the
  `Apero.Cache.Adapter` behaviour.

  ## Supported backends

    * `Apero.Cache.ETS` — in-memory ETS with TTL (built-in, no deps)
    * `Apero.Cache.Redis` — Redis via `redix` (optional dep)
    * `Apero.Cache.Memcached` — Memcached via `memcache` (optional dep)

  ## Usage

      # ETS (built-in)
      {:ok, pid} = Apero.Cache.start_link(Apero.Cache.ETS, name: :my_cache)
      Apero.Cache.put(:my_cache, "key", "value", ttl: 3600)
      Apero.Cache.get(:my_cache, "key") # => {:ok, "value"}

      # Redis
      Apero.Cache.put(:redis_cache, "key", "value")
  """

  @adapters_table :apero_cache_adapters

  @type cache_name :: atom() | pid()

  @doc "Starts a cache backend. Returns `{:ok, pid}`."
  @spec start_link(module(), keyword()) :: GenServer.on_start()
  def start_link(adapter, opts \\ []) do
    ensure_table!()

    case adapter.start_link(opts) do
      {:ok, pid} ->
        if name = Keyword.get(opts, :name) do
          :ets.insert(@adapters_table, {name, adapter})
        end

        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Stores a value. Optional `:ttl` in seconds."
  @spec put(cache_name(), term(), term(), keyword()) :: :ok | {:error, term()}
  def put(cache, key, value, opts \\ []), do: adapter(cache).put(cache, key, value, opts)

  @doc "Retrieves a value. Returns `{:ok, value}` or `{:error, :not_found}`."
  @spec get(cache_name(), term()) :: {:ok, term()} | {:error, :not_found}
  def get(cache, key), do: adapter(cache).get(cache, key)

  @doc "Fetches or computes a value (cache-aside pattern)."
  @spec fetch(cache_name(), term(), (-> term()), keyword()) :: {:ok, term()} | {:error, term()}
  def fetch(cache, key, fun, opts \\ []) when is_function(fun, 0) do
    case get(cache, key) do
      {:ok, value} ->
        {:ok, value}

      {:error, :not_found} ->
        value = fun.()
        put(cache, key, value, opts)
        {:ok, value}
    end
  end

  @doc "Deletes a key."
  @spec delete(cache_name(), term()) :: :ok | {:error, term()}
  def delete(cache, key), do: adapter(cache).delete(cache, key)

  @doc "Clears all keys."
  @spec flush(cache_name()) :: :ok | {:error, term()}
  def flush(cache), do: adapter(cache).flush(cache)

  @doc "Returns the number of keys."
  @spec size(cache_name()) :: {:ok, non_neg_integer()} | {:error, term()}
  def size(cache), do: adapter(cache).size(cache)

  @doc "Returns `true` if the key exists."
  @spec member?(cache_name(), term()) :: boolean()
  def member?(cache, key), do: adapter(cache).member?(cache, key)

  # ═══════════════════════════════════════════════════════════════════════
  # Private
  # ═══════════════════════════════════════════════════════════════════════

  defp adapter(pid) when is_pid(pid), do: Apero.Cache.ETS

  defp adapter(atom) when is_atom(atom) do
    case :ets.lookup(@adapters_table, atom) do
      [{^atom, mod}] -> mod
      [] -> Apero.Cache.ETS
    end
  end

  defp ensure_table! do
    case :ets.info(@adapters_table) do
      :undefined ->
        :ets.new(@adapters_table, [:set, :public, :named_table, write_concurrency: true])

      _ ->
        :ok
    end
  end
end
