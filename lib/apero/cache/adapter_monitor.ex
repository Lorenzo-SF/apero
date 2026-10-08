defmodule Apero.Cache.AdapterMonitor do
  @moduledoc """
  GenServer that monitors every cache adapter started via
  `Apero.Cache.start_link/2` and cleans up the `:apero_cache_adapters`
  ETS entry when the adapter process dies.

  Why a dedicated process? `Apero.Cache.start_link/2` uses
  `Process.monitor(pid)` but the monitor reference is owned by the
  caller (the user code that called start_link).  When that caller
  is short-lived (e.g. a request handler), the `:DOWN` message is
  dropped on the floor.  This GenServer owns the monitor so the
  cleanup happens regardless of the caller's lifecycle.

  Started by `Apero.Cache.Supervisor`.  Not intended for direct use.
  """

  use GenServer

  @table :apero_cache_adapters

  @doc false
  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent
    }
  end

  @doc false
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok), do: {:ok, %{}}

  @doc """
  Registers a monitor for a cache adapter PID and adds the entry to
  the adapters table.

  Called from `Apero.Cache.start_link/2`.  Idempotent.
  """
  @spec track(pid()) :: reference()
  def track(pid) when is_pid(pid) do
    ref = GenServer.call(__MODULE__, {:track, pid})
    ref
  end

  @impl true
  def handle_call({:track, pid}, _from, state) do
    case Map.get(state, pid) do
      nil ->
        ref = Process.monitor(pid)
        {:reply, ref, Map.put(state, pid, ref)}

      ref ->
        # Already tracking this PID; return the existing ref.
        # If the previous monitor was lost, attach a fresh one.
        if Process.info(pid) == nil do
          new_ref = Process.monitor(pid)
          {:reply, new_ref, Map.put(state, pid, new_ref)}
        else
          {:reply, ref, state}
        end
    end
  end

  @impl true
  def handle_cast(_msg, state), do: {:noreply, state}

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    :ets.match_delete(@table, {pid, :_})
    {:noreply, Map.delete(state, pid)}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
