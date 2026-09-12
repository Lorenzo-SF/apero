defmodule Apero.Application do
  alias Apero.Cache.Crypto

  @moduledoc """
  OTP application entry point for Apero.

  Starts:

    * `Apero.RateLimit.Registry` + `Apero.RateLimit.Supervisor` — the
      registry and dynamic supervisor that back named rate-limit buckets.
    * `Apero.Cache.Supervisor` — for cache adapters that need their own
      supervision (ETS-based adapters attach directly; Redis/Memcached
      adapters would spawn a connection GenServer here).
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Initialise the @adapters_table ETS table at boot so concurrent
    # callers never race on first-use creation.
    Apero.Cache.init_adapters_table!()

    children = [
      {Registry, keys: :unique, name: Apero.RateLimit.Registry},
      {DynamicSupervisor, name: Apero.RateLimit.Supervisor, strategy: :one_for_one},
      Apero.Cache.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Apero.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
