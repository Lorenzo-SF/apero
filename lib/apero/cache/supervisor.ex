defmodule Apero.Cache.Supervisor do
  @moduledoc """
  Supervisor for cache adapters.

  Spawns an internal monitor process that tracks every cache adapter
  started via `Apero.Cache.start_link/2` and removes dead entries from
  the `@adapters_table` ETS table.  This prevents the table from
  accumulating stale entries when an adapter crashes.

  ETS-backed adapters (the default `Apero.Cache.ETS`) attach directly
  to the table they manage and do not need their own supervised process.
  Redis/Memcached adapters that need a connection pool should be added
  as children here.
  """

  use Supervisor

  @doc false
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Apero.Cache.AdapterMonitor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

