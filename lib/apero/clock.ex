defmodule Apero.Clock do
  @moduledoc """
  Clock utilities with an injectable, fixed-time override for tests.

  All time-sensitive modules in the kit (`Apero.RateLimit`, `Apero.Retry`,
  botica) should read the current time through `now/0` / `monotonic_ms/0`
  so their behavior can be tested without real sleeps.

  The fixed-time override is stored in a `:persistent_term` so it is
  visible from every process. `with_fixed/2` scopes the override to a
  single function call (restoring the previous state even if `fun`
  raises); `set_fixed!/1` is the global switch for tests.

  ## Examples

      iex> Apero.Clock.with_fixed(~U[2026-07-31 14:00:00.000000Z], fn ->
      ...>   Apero.Clock.now()
      ...> end)
      ~U[2026-07-31 14:00:00.000000Z]
  """

  @override_key {__MODULE__, :fixed}

  @doc """
  Returns the current UTC date and time.

  Returns the fixed time when one has been set via `set_fixed!/1` or
  `with_fixed/2`; otherwise `DateTime.utc_now/0`.

  ## Examples

      iex> is_struct(Apero.Clock.now(), DateTime)
      true
  """
  @spec now() :: DateTime.t()
  def now do
    case :persistent_term.get(@override_key, nil) do
      nil -> DateTime.utc_now()
      %DateTime{} = dt -> dt
    end
  end

  @doc """
  Returns the monotonic time in milliseconds.

  Monotonic time is NOT affected by the fixed-time override: it always
  advances in real time, so it is safe to use for measuring durations in
  rate limiters even when the clock is fixed for tests.

  ## Examples

      iex> is_integer(Apero.Clock.monotonic_ms())
      true
  """
  @spec monotonic_ms() :: integer()
  def monotonic_ms do
    System.monotonic_time(:millisecond)
  end

  @doc """
  Executes `fun` with `dt` as the fixed time, then restores the previous
  clock state (even if `fun` raises).

  ## Parameters

    - `dt` — the fixed date and time to use
    - `fun` — function to execute with the fixed time

  ## Examples

      iex> Apero.Clock.with_fixed(~U[2026-07-31 14:00:00.000000Z], fn ->
      ...>   Apero.Clock.now()
      ...> end)
      ~U[2026-07-31 14:00:00.000000Z]
  """
  @spec with_fixed(DateTime.t(), (() -> result)) :: result when result: any()
  def with_fixed(dt, fun) do
    previous = :persistent_term.get(@override_key, nil)

    try do
      :persistent_term.put(@override_key, dt)
      fun.()
    after
      case previous do
        nil -> :persistent_term.erase(@override_key)
        %DateTime{} -> :persistent_term.put(@override_key, previous)
      end
    end
  end

  @doc """
  Sets (or clears) the fixed time globally.

  Pass `nil` to restore normal (real-clock) behavior. This is a global,
  process-independent override intended for tests; prefer `with_fixed/2`
  when the override should be scoped to a single call.

  ## Examples

      iex> Apero.Clock.set_fixed!(~U[2026-07-31 14:00:00.000000Z])
      :ok
      iex> Apero.Clock.set_fixed!(nil)
      :ok
  """
  @spec set_fixed!(DateTime.t() | nil) :: :ok
  def set_fixed!(nil) do
    :persistent_term.erase(@override_key)
    :ok
  end

  def set_fixed!(%DateTime{} = dt) do
    :persistent_term.put(@override_key, dt)
    :ok
  end
end
