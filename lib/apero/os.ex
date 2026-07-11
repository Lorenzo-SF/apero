defmodule Apero.OS do
  @moduledoc """
  Operating system information utilities for Apero (pure-Elixir subset).

  Provides a minimal interface for querying OS type, hostname, distribution,
  and container/WSL detection using only pure Erlang/Elixir standard library
  calls — no shell execution.

  For shell-based operations (arch, kernel version, CPU count, memory,
  root check) see `Trebejo.OS`.
  """

  @type os_type :: :linux | :macos | :windows | :unknown

  @doc """
  Returns the operating system type.

  Possible values: `:linux`, `:macos`, `:windows`, `:unknown`.
  """
  @spec type() :: os_type()
  def type do
    case :os.type() do
      {:unix, :linux} -> :linux
      {:unix, :darwin} -> :macos
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end

  @doc """
  Returns the machine hostname.
  """
  @dialyzer {:nowarn_function, hostname: 0}
  @spec hostname() :: binary()
  def hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "localhost"
    end
  end

  @doc """
  Returns the distribution name on Linux (reads `/etc/os-release`),
  `"macOS"` on Darwin, or `"Windows"` on win32.
  """
  @spec distro() :: binary()
  def distro do
    case type() do
      :linux -> read_linux_distro()
      :macos -> "macOS"
      :windows -> "Windows"
      _ -> "unknown"
    end
  end

  @doc "Returns true if running under WSL (Windows Subsystem for Linux)."
  @spec wsl?() :: boolean()
  def wsl? do
    type() == :linux and
      (File.exists?("/proc/sys/fs/binfmt_misc/WSLInterop") or
         String.contains?(System.get_env("PATH", ""), "WSL"))
  end

  @doc "Returns true if running inside a container (Docker, Podman, LXC)."
  @spec container?() :: boolean()
  def container? do
    File.exists?("/.dockerenv") or
      File.exists?("/run/.containerenv") or
      String.contains?(safe_read_cgroup(), "docker") or
      String.contains?(safe_read_cgroup(), "lxc") or
      String.contains?(System.get_env("container", ""), "podman")
  end

  defp read_linux_distro do
    case File.read("/etc/os-release") do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.find_value(&find_pretty_name/1) || "Linux"

      _ ->
        "Linux"
    end
  end

  defp find_pretty_name(line) do
    case String.split(line, "=", parts: 2) do
      ["PRETTY_NAME", val] -> String.trim(val, "\"")
      _ -> nil
    end
  end

  defp safe_read_cgroup do
    case File.read("/proc/1/cgroup") do
      {:ok, content} -> content
      _ -> ""
    end
  end
end
