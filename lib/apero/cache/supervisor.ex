defmodule Apero.Cache.Supervisor do
  @moduledoc """
  Supervisor for cache adapters.

  Currently a no-op (the in-memory ETS cache does not need supervision)
  but exists to provide an extension point for adapters that DO need
  their own process (e.g. Redis, Memcached connection pools).
  """

  use Supervisor

  @doc false
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Supervisor.init([], strategy: :one_for_one)
  end
end
