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
    jitter_range = max(1, round(exponential * 0.3))
    jitter = :rand.uniform(jitter_range)
    min(exponential + jitter, max)
  end

  defp default_retry?({:error, _}), do: true
  defp default_retry?({:ok, %{status: s}}) when s >= 500, do: true
  defp default_retry?(_), do: false
end
