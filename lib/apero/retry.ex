defmodule Apero.Retry do
  @moduledoc """
  Retry with exponential backoff and optional jitter.

  ## Example

      Apero.Retry.with(
        fn -> HTTPoison.get(url) end,
        max_attempts: 5,
        base_delay: 100,
        max_delay: 5_000,
        retry_on: fn
          {:ok, %{status: status}} when status >= 500 -> true
          {:error, %HTTPoison.Error{reason: :timeout}} -> true
          _ -> false
        end
      )
  """

  @default_max_attempts 3
  @default_base_delay 100
  @default_max_delay 30_000

  @type predicate :: (any() -> boolean())

  @spec with((-> any()), keyword()) :: any()
  def with(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    base_delay = Keyword.get(opts, :base_delay, @default_base_delay)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)
    should_retry? = Keyword.get(opts, :retry_on, &default_retry?/1)
    on_retry = Keyword.get(opts, :on_retry, fn _ -> :ok end)

    do_retry(fun, 1, max_attempts, base_delay, max_delay, should_retry?, on_retry)
  end

  @doc """
  Non-blocking variant of `with/2` that uses `Process.send_after` between
  attempts instead of `Process.sleep`.

  ## Caveats

  Because the retry is driven by the calling process's mailbox, this
  helper must be called from a process that can receive messages
  (typically a GenServer). The calling process should be ready to
  receive the `{:apero_retry_continue, fun, state}` message; in practice
  this helper is best used from a custom `handle_info/2` that calls
  the next attempt and sends itself another message after the delay.

  Most consumers should prefer the simpler `with/2` (which uses
  `Process.sleep`) unless they are calling from a GenServer mailbox
  loop.
  """
  @spec schedule_next(
          (-> any()),
          integer(),
          integer(),
          integer(),
          integer(),
          (any() -> boolean()),
          (-> any())
        ) :: :ok
  def schedule_next(fun, attempt, max, base, max_d, should_retry?, on_retry) do
    if attempt < max do
      delay = calculate_delay(attempt, base, max_d)
      on_retry.(%{attempt: attempt, delay: delay})

      Process.send_after(
        self(),
        {:apero_retry, fun, attempt + 1, max, base, max_d, should_retry?, on_retry},
        delay
      )

      :ok
    else
      :ok
    end
  end

  @doc """
  Handles a `{:apero_retry, ...}` message produced by `schedule_next/7`.
  Runs the next attempt; if it succeeds or exhausts retries, returns the
  result via `{:apero_retry_done, result}`. Otherwise schedules the
  next retry.

  This is the GenServer hook for non-blocking retry.
  """
  @spec handle_message(
          {:apero_retry, (-> any()), integer(), integer(), integer(), integer(),
           (any() -> boolean()), (-> any())}
        ) :: any()
  def handle_message({:apero_retry, fun, attempt, max, base, max_d, should_retry?, on_retry}) do
    result = fun.()

    cond do
      not should_retry?.(result) ->
        {:apero_retry_done, result}

      attempt >= max ->
        {:apero_retry_done, result}

      true ->
        delay = calculate_delay(attempt, base, max_d)
        on_retry.(%{attempt: attempt, result: result, delay: delay})

        Process.send_after(
          self(),
          {:apero_retry, fun, attempt + 1, max, base, max_d, should_retry?, on_retry},
          delay
        )

        {:apero_retry_pending, attempt + 1}
    end
  end

  defp do_retry(fun, attempt, max, base, max_d, should_retry?, on_retry) do
    result = fun.()

    cond do
      not should_retry?.(result) ->
        result

      attempt >= max ->
        result

      true ->
        delay = calculate_delay(attempt, base, max_d)
        on_retry.(%{attempt: attempt, result: result, delay: delay})
        Process.sleep(delay)
        do_retry(fun, attempt + 1, max, base, max_d, should_retry?, on_retry)
    end
  end

  defp calculate_delay(attempt, base, max) do
    exponential = round(base * :math.pow(2, attempt - 1))
    max(1, round(:rand.uniform() * min(exponential, max)))
  end

  defp default_retry?({:error, _}), do: true
  defp default_retry?({:ok, %{status: s}}) when s >= 500, do: true
  defp default_retry?(_), do: false
end
