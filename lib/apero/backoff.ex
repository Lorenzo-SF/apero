defmodule Apero.Backoff do
  @moduledoc """
  Exponential backoff with jitter for retry strategies.

  This module replaces the 5 custom retry-delay implementations currently
  spread across candil/delfos/trebejo (see ROADMAP A-2). It supports two
  jitter strategies:

    * `:full` — `random(0, base * factor^attempt)` capped at `max_ms`.
      Best for avoiding thundering herds when many clients retry at once.
    * `:decorrelated` (default) — `min(max, random(prev, prev * factor))`
      where `prev` is the previous *actual* delay. Keeps the variance low
      and the mean close to the exponential curve.

  `delay/2` is pure (only consumes the `:rand` state) so it is fully
  testable with a seeded `:rand`; `sleep/2` applies the delay.

  ## Examples

      iex> backoff = Apero.Backoff.new(100, 1000)
      iex> delay = Apero.Backoff.delay(backoff, 0)
      iex> delay >= 0 and delay <= 1000
      true
  """

  @typedoc """
  Jitter strategy: `:full` (uniform in `[0, cap]`) or `:decorrelated`
  (uniform between the previous delay and the previous delay × factor).
  """
  @type jitter :: :full | :decorrelated

  @typedoc "Backoff configuration."
  @type t :: %__MODULE__{
          base_ms: non_neg_integer(),
          max_ms: non_neg_integer(),
          factor: float(),
          jitter: jitter()
        }

  defstruct base_ms: 100,
            max_ms: 30_000,
            factor: 2.0,
            jitter: :decorrelated

  @doc """
  Creates a new backoff configuration.

  ## Parameters

    - `base_ms` — initial delay in milliseconds
    - `max_ms` — maximum delay in milliseconds
    - `factor` — exponential growth factor (default: 2.0)
    - `jitter` — jitter strategy (`:full` or `:decorrelated`)

  ## Examples

      iex> Apero.Backoff.new(100, 1000)
      %Apero.Backoff{base_ms: 100, max_ms: 1000, factor: 2.0, jitter: :decorrelated}

      iex> Apero.Backoff.new(50, 500, 3.0, :full)
      %Apero.Backoff{base_ms: 50, max_ms: 500, factor: 3.0, jitter: :full}
  """
  @spec new(non_neg_integer(), non_neg_integer(), float(), jitter()) :: t()
  def new(base_ms, max_ms, factor \\ 2.0, jitter \\ :decorrelated) do
    %__MODULE__{
      base_ms: base_ms,
      max_ms: max_ms,
      factor: factor,
      jitter: jitter
    }
  end

  @doc """
  Calculates the delay for a given attempt using the backoff configuration.

  ## Parameters

    - `backoff` — backoff configuration
    - `attempt` — attempt number (0-based)

  The result is always in `[0, max_ms]`. With `:full` jitter the delay is
  uniform in `[0, min(max_ms, base * factor^attempt)]`; with
  `:decorrelated` it is uniform between the previous delay and the
  previous delay × factor, capped at `max_ms` (attempt 0 uses `base_ms`
  as the previous delay).

  ## Examples

      iex> backoff = Apero.Backoff.new(100, 1000)
      iex> delay = Apero.Backoff.delay(backoff, 0)
      iex> delay >= 0 and delay <= 1000
      true
  """
  @spec delay(t(), non_neg_integer()) :: non_neg_integer()
  def delay(%__MODULE__{} = backoff, attempt) do
    case backoff.jitter do
      :full -> full_jitter(backoff, attempt)
      :decorrelated -> decorrelated_jitter(backoff, attempt)
    end
  end

  @doc """
  Sleeps for the calculated delay for a given attempt.

  ## Parameters

    - `backoff` — backoff configuration
    - `attempt` — attempt number (0-based)

  ## Examples

      iex> backoff = Apero.Backoff.new(1, 10)
      iex> Apero.Backoff.sleep(backoff, 0)
      :ok
  """
  @spec sleep(t(), non_neg_integer()) :: :ok
  def sleep(%__MODULE__{} = backoff, attempt) do
    delay(backoff, attempt) |> Process.sleep()
    :ok
  end

  # -- private ----------------------------------------------------------

  defp full_jitter(backoff, attempt) do
    cap = exponential_cap(backoff, attempt)
    :rand.uniform(cap + 1) - 1
  end

  defp decorrelated_jitter(backoff, 0) do
    # No previous delay: pick from [base_ms, base_ms * factor] capped.
    low = backoff.base_ms
    high = min(backoff.max_ms, round(low * backoff.factor))
    low + :rand.uniform(high - low + 1) - 1
  end

  defp decorrelated_jitter(backoff, attempt) do
    # Reuse the deterministic exponential delay of the previous attempt as
    # the reference point; keep the actual draw in [prev, prev * factor].
    prev = exponential_cap(backoff, attempt - 1)
    low = prev
    high = min(backoff.max_ms, round(prev * backoff.factor))
    low + :rand.uniform(high - low + 1) - 1
  end

  defp exponential_cap(backoff, attempt) do
    min(backoff.max_ms, round(backoff.base_ms * :math.pow(backoff.factor, attempt)))
  end
end
