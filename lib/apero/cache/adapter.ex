defmodule Apero.Cache.Adapter do
  @moduledoc """
  Behaviour for cache backends.

  Implement this behaviour to add support for a new cache system.
  """

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback put(term(), term(), term(), keyword()) :: :ok | {:error, term()}
  @callback get(term(), term()) :: {:ok, term()} | {:error, :not_found}
  @callback delete(term(), term()) :: :ok | {:error, term()}
  @callback flush(term()) :: :ok | {:error, term()}
  @callback size(term()) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback member?(term(), term()) :: boolean()
end
