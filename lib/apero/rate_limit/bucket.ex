defmodule Apero.RateLimit.Bucket do
  @moduledoc """
  Backing `GenServer` for a named rate limit bucket.

  Each bucket is a single process registered under
  `Apero.RateLimit.Registry`, which serializes all mutations for a given
  name (no race conditions under concurrency). The current state is
  mirrored into the `:apero_rate_limit` ETS table for cheap reads and
  diagnostics.

  You normally do not use this module directly — use `Apero.RateLimit`.
  """

  use GenServer

  alias Apero.Clock
  alias Apero.RateLimit

  @table Apero.RateLimit.table()

  @doc false
  def start_link(%RateLimit{} = config) do
    GenServer.start_link(__MODULE__, config, name: via(config.name))
  end

  @doc false
  def via(name) do
    {:via, Registry, {Apero.RateLimit.Registry, name}}
  end

  @doc false
  def ensure_started(%RateLimit{} = config) do
    ensure_table()

    case Registry.lookup(Apero.RateLimit.Registry, config.name) do
      [{_pid, _}] ->
        :ok

      [] ->
        case DynamicSupervisor.start_child(Apero.RateLimit.Supervisor, {__MODULE__, config}) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            raise "cannot start rate limit bucket #{inspect(config.name)}: #{inspect(reason)}"
        end
    end
  end

  @doc false
  def allow?(name, n) do
    GenServer.call(via(name), {:allow, n})
  end

  @doc false
  def state(name) do
    case :ets.lookup(@table, name) do
      [{_, state}] -> state
      [] -> nil
    end
  end

  @impl true
  def init(%RateLimit{} = config) do
    now = Clock.monotonic_ms()

    state = %{
      config: config,
      level: initial_level(config),
      updated_at: now
    }

    :ets.insert(@table, {config.name, state})
    {:ok, state}
  end

  @impl true
  def handle_call({:allow, n}, _from, state) do
    {allowed, state} = consume(state, n)
    :ets.insert(@table, {state.config.name, state})
    {:reply, allowed, state}
  end

  # -- private ----------------------------------------------------------

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _ ->
        :ok
    end
  end

  defp initial_level(%RateLimit{bucket: :leaky}), do: 0.0
  defp initial_level(%RateLimit{capacity: capacity}), do: capacity * 1.0

  defp consume(state, n) do
    now = Clock.monotonic_ms()
    elapsed_s = (now - state.updated_at) / 1000

    case state.config.bucket do
      :token -> consume_token(state, n, now, elapsed_s)
      :leaky -> consume_leaky(state, n, now, elapsed_s)
    end
  end

  defp consume_token(state, n, now, elapsed_s) do
    refill = state.config.refill_per_second * elapsed_s
    level = min(state.config.capacity, state.level + refill)

    if level >= n do
      {true, %{state | level: level - n, updated_at: now}}
    else
      {false, %{state | level: level, updated_at: now}}
    end
  end

  defp consume_leaky(state, n, now, elapsed_s) do
    drained = state.config.refill_per_second * elapsed_s
    level = max(0.0, state.level - drained)

    if level + n <= state.config.capacity do
      {true, %{state | level: level + n, updated_at: now}}
    else
      {false, %{state | level: level, updated_at: now}}
    end
  end
end
