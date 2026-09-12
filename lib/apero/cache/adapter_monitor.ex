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
    ref = Process.monitor(pid)
    GenServer.cast(__MODULE__, {:track, pid, ref})
    ref
  end

  @impl true
  def handle_cast({:track, pid, ref}, state) do
    Process.monitor(pid)
    {:noreply, Map.put(state, ref, pid)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    # Remove any entries in @adapters_table that point to the dead PID.
    # We don't track which PID each ref belongs to (the ref->pid map is
    # already removed below), but the table can only have one entry per
    # PID so the match is unambiguous.
    :ets.match_delete(@table, {pid_for_ref(state, ref), :_})
    {:noreply, Map.delete(state, ref)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp pid_for_ref(state, ref) do
    Map.get(state, ref)
  end
end
