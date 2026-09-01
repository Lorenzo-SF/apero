defmodule Apero.RateLimit do
  @moduledoc """
  Rate limiting with token bucket and leaky bucket algorithms.

  Buckets are identified by a `name` atom. Each named bucket is backed by
  a `GenServer` (registered via `Apero.RateLimit.Registry`) so all
  operations against the same bucket are serialized — safe under
  concurrency. State is mirrored into the public ETS table
  `:apero_rate_limit` (created with `read_concurrency: true`) for cheap
  reads and diagnostics.

  ## Example

      Apero.RateLimit.new(name: :llm_api, capacity: 10, refill_per_second: 1.0)
      Apero.RateLimit.allow?(:llm_api)          #=> true
      Apero.RateLimit.check(:llm_api, 3)        #=> :ok
      Apero.RateLimit.wait(:llm_api, 1, 2000)   #=> :ok
  """

  alias Apero.Clock
  alias Apero.RateLimit.Bucket

  @table :apero_rate_limit

  @typedoc "Rate limiter configuration struct."
  @type t :: %__MODULE__{
          name: atom(),
          capacity: pos_integer(),
          refill_per_second: float(),
          bucket: :token | :leaky
        }

  defstruct name: nil,
            capacity: 10,
            refill_per_second: 1.0,
            bucket: :token

  @doc """
  Creates (or fetches) a rate limit configuration.

  If a bucket with the same `name` already exists, its existing
  configuration is returned unchanged.

  ## Options

    - `name` — (required) atom identifying the bucket
    - `capacity` — max tokens (token bucket) or max in-flight work
      (leaky bucket), default: 10
    - `refill_per_second` — tokens added per second (token bucket) or
      work drained per second (leaky bucket), default: 1.0
    - `bucket` — `:token` (default) or `:leaky`

  ## Examples

      iex> rl = Apero.RateLimit.new(name: :api, capacity: 5, refill_per_second: 2.0, bucket: :leaky)
      iex> rl.capacity
      5
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)

    config = %__MODULE__{
      name: name,
      capacity: Keyword.get(opts, :capacity, 10),
      refill_per_second: Keyword.get(opts, :refill_per_second, 1.0),
      bucket: Keyword.get(opts, :bucket, :token)
    }

    Bucket.ensure_started(config)
    config
  end

  @doc """
  Returns `true` if `n` units can be consumed, consuming them.

  If the bucket does not exist yet, it is created with default settings
  (capacity 10, refill 1.0/s, token bucket).

  ## Examples

      iex> rl = Apero.RateLimit.new(name: :api, capacity: 1)
      iex> Apero.RateLimit.allow?(:api, 1)
      true
      iex> Apero.RateLimit.allow?(:api, 1)
      false
  """
  @spec allow?(atom(), pos_integer()) :: boolean()
  def allow?(name, n \\ 1) when is_atom(name) and is_integer(n) and n > 0 do
    Bucket.ensure_started(%__MODULE__{name: name})
    Bucket.allow?(name, n)
  end

  @doc """
  Checks whether `n` units can be consumed, consuming them.

  Returns `:ok` when allowed or `{:error, :rate_limited}` otherwise.

  ## Examples

      iex> rl = Apero.RateLimit.new(name: :api, capacity: 1)
      iex> Apero.RateLimit.check(:api, 1)
      :ok
      iex> Apero.RateLimit.check(:api, 1)
      {:error, :rate_limited}
  """
  @spec check(atom(), pos_integer()) :: :ok | {:error, :rate_limited}
  def check(name, n \\ 1) when is_atom(name) and is_integer(n) and n > 0 do
    if allow?(name, n), do: :ok, else: {:error, :rate_limited}
  end

  @doc """
  Waits until `n` units can be consumed or `timeout_ms` elapses.

  Polls every 10ms, so it never blocks the BEAM scheduler. Returns `:ok`
  on success, `{:error, :timeout}` if the deadline passes, or
  `{:error, :rate_limited}` if the bucket refills at `0.0`/s (it can
  never free capacity again).

  ## Examples

      iex> rl = Apero.RateLimit.new(name: :api, capacity: 1, refill_per_second: 100.0)
      iex> Apero.RateLimit.check(:api, 1)
      :ok
      iex> Apero.RateLimit.wait(:api, 1, 200)
      :ok
  """
  @spec wait(atom(), pos_integer(), non_neg_integer()) ::
          :ok | {:error, :timeout | :rate_limited}
  def wait(name, n \\ 1, timeout_ms \\ 5000)
      when is_atom(name) and is_integer(n) and n > 0 and is_integer(timeout_ms) and
             timeout_ms >= 0 do
    Bucket.ensure_started(%__MODULE__{name: name})

    cond do
      Bucket.allow?(name, n) ->
        :ok

      zero_refill?(name) ->
        {:error, :rate_limited}

      true ->
        deadline = Clock.monotonic_ms() + timeout_ms
        poll(name, n, deadline)
    end
  end

  @doc false
  def table, do: @table

  # -- private ----------------------------------------------------------

  defp zero_refill?(name) do
    case :ets.lookup(@table, name) do
      [{_, %{config: %__MODULE__{refill_per_second: refill}}}] -> refill <= 0
      _ -> false
    end
  end

  defp poll(name, n, deadline) do
    if Bucket.allow?(name, n) do
      :ok
    else
      now = Clock.monotonic_ms()

      if now >= deadline do
        {:error, :timeout}
      else
        Process.sleep(10)
        poll(name, n, deadline)
      end
    end
  end
end
