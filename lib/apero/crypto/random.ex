defmodule Apero.Crypto.Random do
  @moduledoc """
  Random generation utilities for cryptographic purposes.

  Provides secure random generation for keys, tokens, passwords, and
  timing-safe comparison.
  """

  @aes_key_bytes 32

  @doc "Generates a random 256-bit key."
  @spec generate_key() :: binary()
  def generate_key, do: :crypto.strong_rand_bytes(@aes_key_bytes)

  @doc "Generates a random hex string."
  @spec random_hex(non_neg_integer()) :: binary()
  def random_hex(bytes \\ 32), do: :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)

  @doc "Generates a random URL-safe token."
  @spec random_token(non_neg_integer()) :: binary()
  def random_token(bytes \\ 32),
    do: :crypto.strong_rand_bytes(bytes) |> Base.url_encode64(padding: false)

  @doc "Generates a random password with configurable length and character sets."
  @spec random_password(non_neg_integer(), keyword()) :: binary()
  def random_password(length \\ 24, opts \\ []) do
    upper = Keyword.get(opts, :upper, true)
    lower = Keyword.get(opts, :lower, true)
    digits = Keyword.get(opts, :digits, true)
    symbols = Keyword.get(opts, :symbols, false)

    charset = ""
    charset = if upper, do: charset <> "ABCDEFGHIJKLMNOPQRSTUVWXYZ", else: charset
    charset = if lower, do: charset <> "abcdefghijklmnopqrstuvwxyz", else: charset
    charset = if digits, do: charset <> "0123456789", else: charset
    charset = if symbols, do: charset <> "!@#$%^&*()_+-=[]{}|;:,.<>?", else: charset

    chars = String.graphemes(charset)
    max = length(chars) - 1

    Enum.map_join(1..length, fn _ ->
      <<idx::size(8)>> = :crypto.strong_rand_bytes(1)
      Enum.at(chars, rem(idx, max + 1))
    end)
  end

  @doc "Timing-safe string comparison."
  @spec secure_compare(binary(), binary()) :: boolean()
  def secure_compare(a, b) when is_binary(a) and is_binary(b) and byte_size(a) == byte_size(b),
    do: :crypto.hash_equals(a, b)

  def secure_compare(_, _), do: false
end
