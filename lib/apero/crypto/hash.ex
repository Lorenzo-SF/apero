defmodule Apero.Crypto.Hash do
  @moduledoc """
  Cryptographic hashing functions.

  Provides SHA-256, SHA-512, MD5, and HMAC hashing, all returning
  lowercase hex-encoded strings.

  ## Examples

      iex> Apero.Crypto.Hash.sha256("hello")
      "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

  """

  @doc "SHA-256 hash (hex encoded)."
  @spec sha256(binary()) :: binary()
  def sha256(data) when is_binary(data), do: hash(:sha256, data)

  @doc "SHA-512 hash (hex encoded)."
  @spec sha512(binary()) :: binary()
  def sha512(data) when is_binary(data), do: hash(:sha512, data)

  @doc "MD5 hash (hex encoded). NOTE: MD5 is cryptographically broken — only for checksums."
  @spec md5(binary()) :: binary()
  def md5(data) when is_binary(data), do: hash(:md5, data)

  @doc "HMAC-SHA256 (hex encoded)."
  @spec hmac(binary(), binary()) :: binary()
  def hmac(secret, data) when is_binary(secret) and is_binary(data) do
    :crypto.mac(:hmac, :sha256, secret, data) |> Base.encode16(case: :lower)
  end

  # ── Private ────────────────────────────────────────────────────────

  defp hash(algo, data), do: :crypto.hash(algo, data) |> Base.encode16(case: :lower)
end
