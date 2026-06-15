defmodule Apero.OS do
  @moduledoc """
  Operating system information utilities for Apero.

  Provides a unified interface for querying system metadata regardless of
  the underlying platform (Linux, macOS, Windows).

  ## Example

      iex> info = Apero.OS.info()
      iex> info.type in [:linux, :macos, :windows, :unknown]
      true

  """

  @type os_type :: :linux | :macos | :windows | :unknown
  @type arch :: :x86_64 | :arm64 | :arm | :i386 | :unknown

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
  Returns the CPU architecture of the current machine.

  Possible values: `:x86_64`, `:arm64`, `:arm`, `:i386`, `:unknown`.
  """
  @spec arch() :: arch()
  def arch do
    System.get_env("PROCESSOR_ARCHITECTURE") || uname_m() |> parse_arch()
  end

  defp parse_arch("x86_64"), do: :x86_64
  defp parse_arch("amd64"), do: :x86_64
  defp parse_arch("arm64"), do: :arm64
  defp parse_arch("aarch64"), do: :arm64
  defp parse_arch("armv7l"), do: :arm
  defp parse_arch("i386"), do: :i386
  defp parse_arch("i686"), do: :i386
  defp parse_arch(_), do: :unknown

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
  Returns the OS kernel version string, or `"unknown"` if unavailable.
  """
  @spec kernel_version() :: binary()
  def kernel_version do
    case :os.type() do
      {:unix, _} ->
        case System.cmd("uname", ["-r"], stderr_to_stdout: true) do
          {out, 0} -> String.trim(out)
          _ -> "unknown"
        end

      {:win32, _} ->
        case System.cmd("cmd", ["/c", "ver"], stderr_to_stdout: true) do
          {out, 0} -> String.trim(out)
          _ -> "unknown"
        end
    end
  end

  @doc """
  Returns the distribution name on Linux (reads `/etc/os-release`),
  `"macOS"` on Darwin, or `"Windows"` on win32.
  """
  @spec distro() :: binary()
  def distro do
    case :os.type() do
      {:unix, :linux} -> read_linux_distro()
      {:unix, :darwin} -> "macOS"
      {:win32, _} -> "Windows"
      _ -> "unknown"
    end
  end

  @doc """
  Returns a consolidated map of system information.

  Keys: `:type`, `:arch`, `:hostname`, `:distro`, `:kernel_version`,
  `:cpu_count`, `:total_memory_mb`.
  """
  @spec info() :: map()
  def info do
    %{
      type: type(),
      arch: arch(),
      hostname: hostname(),
      distro: distro(),
      kernel_version: kernel_version(),
      cpu_count: cpu_count(),
      total_memory_mb: total_memory_mb()
    }
  end

  @doc """
  Returns the number of logical CPU cores available to the OS.
  """
  @spec cpu_count() :: pos_integer()
  def cpu_count do
    case :os.type() do
      {:unix, :linux} ->
        case System.cmd("nproc", [], stderr_to_stdout: true) do
          {out, 0} -> parse_integer(out, System.schedulers_online())
          _ -> System.schedulers_online()
        end

      {:unix, :darwin} ->
        case System.cmd("sysctl", ["-n", "hw.logicalcpu"], stderr_to_stdout: true) do
          {out, 0} -> parse_integer(out, System.schedulers_online())
          _ -> System.schedulers_online()
        end

      _ ->
        System.schedulers_online()
    end
  end

  @doc """
  Returns the total system RAM in megabytes, or `0` if unavailable.
  """
  @spec total_memory_mb() :: non_neg_integer()
  def total_memory_mb do
    case :os.type() do
      {:unix, :linux} -> read_meminfo()
      {:unix, :darwin} -> read_macos_memory()
      _ -> 0
    end
  end

  @doc """
  Returns `true` if the current process is running as root / Administrator.
  """
  @spec root?() :: boolean()
  def root? do
    case :os.type() do
      {:unix, _} ->
        case System.cmd("id", ["-u"], stderr_to_stdout: true) do
          {output, 0} -> String.trim(output) == "0"
          _ -> false
        end

      {:win32, _} ->
        case System.cmd("net", ["session"], stderr_to_stdout: true) do
          {_out, 0} -> true
          _ -> false
        end
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

  defp safe_read_cgroup do
    case File.read("/proc/1/cgroup") do
      {:ok, content} -> content
      _ -> ""
    end
  end

  defp uname_m do
    case System.cmd("uname", ["-m"], stderr_to_stdout: true) do
      {out, 0} -> String.trim(out)
      _ -> ""
    end
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

  defp read_meminfo do
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.find_value(&find_mem_total/1) || 0

      _ ->
        0
    end
  end

  defp read_macos_memory do
    case System.cmd("sysctl", ["-n", "hw.memsize"], stderr_to_stdout: true) do
      {out, 0} ->
        out |> String.trim() |> parse_integer(0) |> div(1_024 * 1_024)

      _ ->
        0
    end
  end

  defp parse_integer(str, default) do
    case Integer.parse(String.trim(str)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp find_pretty_name(line) do
    case String.split(line, "=", parts: 2) do
      ["PRETTY_NAME", val] -> String.trim(val, "\"")
      _ -> nil
    end
  end

  defp find_mem_total(line) do
    case Regex.run(~r/^MemTotal:\s+(\d+)\s+kB/, line) do
      [_, kb] -> div(String.to_integer(kb), 1_024)
      _ -> nil
    end
  end
end
