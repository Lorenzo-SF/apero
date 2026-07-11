defmodule Apero.Network do
  @moduledoc """
  Network utilities for Apero — pure Erlang, no shell execution.

  Provides DNS resolution using only the Erlang standard library.
  For TCP port checks and ICMP ping see `Trebejo.Network`.
  """

  @doc """
  Resolves a hostname to a list of IP addresses.

  Returns `{:ok, [String.t()]}` or `{:error, :nxdomain}` on failure.
  """
  @spec resolve(String.t()) :: {:ok, [String.t()]} | {:error, atom()}
  def resolve(host) do
    case :inet.gethostbyname(String.to_charlist(host)) do
      {:ok, {:hostent, _, _, _, _, addresses}} ->
        {:ok, Enum.map(addresses, fn addr -> addr |> :inet.ntoa() |> List.to_string() end)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
