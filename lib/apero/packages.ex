defmodule Apero.Packages do
  @moduledoc """
  Package manager detection — pure, no command execution.

  Detects the available system package manager(s) via PATH lookup.
  For package installation and querying see `Trebejo.Packages`.
  """

  alias Apero.OS
  alias Apero.Proc

  @type manager ::
          :apt
          | :apt_get
          | :brew
          | :pacman
          | :yum
          | :dnf
          | :apk
          | :zypper
          | :pkg
          | :winget
          | :choco
          | :port
          | :nix

  @typedoc "Map of detected managers and their binary paths."
  @type detection :: %{manager => String.t()}

  # Registry of known package managers per OS, in priority order.
  @managers %{
    linux: [
      :apt_get,
      :apt,
      :pacman,
      :dnf,
      :yum,
      :zypper,
      :apk,
      :nix,
      :port
    ],
    macos: [
      :brew,
      :port,
      :nix
    ],
    windows: [
      :winget,
      :choco
    ]
  }

  @doc """
  Returns a map of detected package managers and their binary paths.

  ## Examples

      iex> Apero.Packages.detect()
      %{brew: "/opt/homebrew/bin/brew"}
  """
  @spec detect() :: detection()
  def detect do
    os = OS.type()
    candidates = Map.get(@managers, os, [])

    candidates
    |> Enum.map(&{&1, manager_binary(&1)})
    |> Enum.filter(fn {_, path} -> path != nil end)
    |> Map.new()
  end

  @doc """
  Returns the preferred package manager for the current system, or `nil`.

  The preferred manager is the first one detected in priority order.
  """
  @spec preferred() :: manager | nil
  def preferred do
    case detect() |> Map.to_list() |> List.first() do
      {mgr, _} -> mgr
      nil -> nil
    end
  end

  @doc """
  Returns `true` if the given package manager is available on the system.
  """
  @spec available?(manager) :: boolean()
  def available?(manager) when is_atom(manager) do
    Proc.command_exists?(manager_binary(manager))
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp manager_binary(:apt), do: "apt"
  defp manager_binary(:apt_get), do: "apt-get"
  defp manager_binary(:brew), do: "brew"
  defp manager_binary(:pacman), do: "pacman"
  defp manager_binary(:yum), do: "yum"
  defp manager_binary(:dnf), do: "dnf"
  defp manager_binary(:apk), do: "apk"
  defp manager_binary(:zypper), do: "zypper"
  defp manager_binary(:pkg), do: "pkg"
  defp manager_binary(:winget), do: "winget"
  defp manager_binary(:choco), do: "choco"
  defp manager_binary(:port), do: "port"
  defp manager_binary(:nix), do: "nix"
end
