defmodule Apero.File.Watcher do
  @moduledoc """
  File system watcher GenServer.

  This is a pure OTP GenServer that wraps `file_system` for watching
  file changes. The `watch/3` convenience function moved to `Trebejo.File`
  in v3.0.0 because it depends on `Arrea.WorkerSupervisor`, but this
  GenServer remains in Apero.

  You normally use `Trebejo.File.watch/3` rather than instantiating this
  directly.
  """
  use GenServer

  @type event :: :modified | :created | :deleted | :renamed | :isdir | :attribute | atom()
  @type callback :: ([{binary(), [event()]}] -> any())

  @doc false
  @spec child_spec(keyword() | map()) :: map()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :transient
    }
  end

  @spec start_link(keyword() | map()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    dirs = Keyword.fetch!(opts, :dirs)
    callback = Keyword.fetch!(opts, :callback)
    debounce_ms = Keyword.get(opts, :debounce_ms, 100)

    GenServer.start_link(
      __MODULE__,
      %{dirs: dirs, callback: callback, debounce_ms: debounce_ms, timer: nil},
      name: opts[:name]
    )
  end

  def start_link(opts) when is_map(opts) do
    start_link(Map.to_list(opts))
  end

  @impl GenServer
  def init(%{dirs: dirs} = state) do
    case FileSystem.start_link(dirs: dirs) do
      {:ok, watcher_pid} ->
        FileSystem.subscribe(watcher_pid)
        {:ok, state |> Map.put(:watcher_pid, watcher_pid) |> Map.put_new(:pending, [])}

      {:error, reason} ->
        {:stop, reason}

      :ignore ->
        :ignore
    end
  end

  @impl GenServer
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    state = schedule_debounce(state, {path, events})
    {:noreply, state}
  end

  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    {:noreply, state}
  end

  def handle_info(:flush, %{callback: callback} = state) do
    pending = Map.get(state, :pending, [])
    callback.(Enum.reverse(pending))
    {:noreply, Map.merge(state, %{timer: nil, pending: []})}
  end

  @impl GenServer
  def terminate(_reason, %{watcher_pid: pid}) when is_pid(pid) do
    GenServer.stop(pid, :normal)
  end

  def terminate(_reason, _state), do: :ok

  defp schedule_debounce(state, event) do
    if state.timer, do: Process.cancel_timer(state.timer)
    pending = [event | Map.get(state, :pending, [])]
    timer = Process.send_after(self(), :flush, state.debounce_ms)
    Map.merge(state, %{timer: timer, pending: pending})
  end
end
