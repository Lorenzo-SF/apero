defmodule Apero.Cache.ETS do
  @moduledoc """
  ETS-backed cache with TTL support.

  Each cache is an independent named ETS table managed by its own GenServer.
  Entries expire automatically via lazy removal on read and periodic sweeping.
  """
  @behaviour Apero.Cache.Adapter

  use GenServer

  defstruct [:name, :table, :timer, ttl: 3600]

  @impl true
  def start_link(opts) do
    name = Keyword.get(opts, :name, make_ref())
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    ttl = Keyword.get(opts, :ttl, 3600)
    name = Keyword.get(opts, :name, make_ref())
    table = :ets.new(name, [:set, :public, :named_table])
    timer = Process.send_after(self(), :sweep, max(ttl * 1000, 60_000))
    {:ok, %__MODULE__{name: name, table: table, timer: timer, ttl: ttl}}
  end

  @impl true
  def put(cache, key, value, opts) do
    ttl = Keyword.get(opts, :ttl, 3600)
    expires_at = System.system_time(:second) + ttl
    :ets.insert(table(cache), {key, value, expires_at})
    :ok
  end

  @impl true
  def get(cache, key) do
    case :ets.lookup(table(cache), key) do
      [{^key, value, expires_at}] ->
        if System.system_time(:second) <= expires_at do
          {:ok, value}
        else
          :ets.delete(table(cache), key)
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @impl true
  def delete(cache, key) do
    :ets.delete(table(cache), key)
    :ok
  end

  @impl true
  def flush(cache) do
    :ets.delete_all_objects(table(cache))
    :ok
  end

  @impl true
  def size(cache) do
    {:ok, :ets.info(table(cache), :size)}
  end

  @impl true
  def member?(cache, key) do
    case get(cache, key) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @impl true
  def handle_call(:table_name, _from, state), do: {:reply, state.table, state}

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:second)
    :ets.select_delete(state.table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    timer = Process.send_after(self(), :sweep, max(state.ttl * 1000, 60_000))
    {:noreply, %{state | timer: timer}}
  end

  defp table(pid) when is_pid(pid), do: GenServer.call(pid, :table_name)
  defp table(atom) when is_atom(atom), do: atom
end
