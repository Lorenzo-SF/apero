defmodule Apero.Http.Finch do
  @moduledoc """
  Manages the lifecycle of the Finch HTTP pool used by `Apero.Http`.

  Starts a dedicated Finch instance on demand. Safe to call multiple
  times — `ensure_started/0` is a no-op if Finch is already running.

  Uses a custom pool configuration (pool size: 10, pool count: 1).
  Override via application config:

      config :apero, :http_finch_pools, %{
        default: [size: 20, count: 2]
      }
  """

  @finch_name Apero.Http.Finch

  @doc """
  Starts the Finch pool under `Apero.Http.Finch` if not already running.
  Always returns `:ok`.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    _ = Application.ensure_all_started(:finch)

    case Process.whereis(@finch_name) do
      nil -> do_start_link()
      _pid -> :ok
    end

    :ok
  end

  defp do_start_link do
    pools = Application.get_env(:apero, :http_finch_pools, %{default: [size: 10, count: 1]})

    case Finch.start_link(name: @finch_name, pools: pools) do
      {:ok, _pid} ->
        Process.sleep(50)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, _reason} ->
        :ok
    end
  end
end
