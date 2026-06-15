defmodule Apero.Application do
  @moduledoc """
  OTP application entry point for Apero.

  Starts:

    * `Apero.Cache.Supervisor` — for cache adapters that need their own
      supervision (ETS-based adapters attach directly; Redis/Memcached
      adapters would spawn a connection GenServer here).
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Apero.Cache.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Apero.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
