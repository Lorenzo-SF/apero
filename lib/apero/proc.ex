defmodule Apero.Proc do
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  @moduledoc """
  Process and executable utilities for Apero.

  Provides helpers for checking command availability, finding executables,
  inspecting running processes, sending signals, and viewing process logs.
  """

  alias Apero.OS

  @doc "Returns `true` if the given command exists in the system `PATH`."
  @spec command_exists?(String.t()) :: boolean()
  def command_exists?(cmd) when is_binary(cmd) and byte_size(cmd) > 0,
    do: System.find_executable(cmd) != nil

  def command_exists?(_), do: false

  @doc "Returns the full path of a command if found, or `nil`."
  @spec which(String.t()) :: String.t() | nil
  def which(cmd), do: System.find_executable(cmd)

  @doc "Filters a list of commands to only those available on the system."
  @spec available_commands([String.t()]) :: [String.t()]
  def available_commands(commands) when is_list(commands),
    do: Enum.filter(commands, &command_exists?/1)

  @doc "Returns a map of `command => path` for all found commands."
  @spec locate_commands([String.t()]) :: %{String.t() => String.t()}
  def locate_commands(commands) when is_list(commands) do
    commands
    |> Enum.map(&{&1, which(&1)})
    |> Enum.filter(fn {_, path} -> path != nil end)
    |> Map.new()
  end

  @doc "Returns the OS process ID of the BEAM VM."
  @spec os_pid() :: non_neg_integer()
  def os_pid, do: :os.getpid() |> List.to_string() |> String.to_integer()

  @doc "Returns the number of scheduler threads."
  @spec scheduler_count() :: non_neg_integer()
  def scheduler_count, do: :erlang.system_info(:schedulers)

  @doc "Returns the VM memory usage in bytes."
  @spec vm_memory() :: non_neg_integer()
  def vm_memory, do: :erlang.memory(:total)

  @doc "Returns the VM uptime in milliseconds."
  @spec vm_uptime() :: non_neg_integer()
  def vm_uptime do
    :erlang.statistics(:wall_clock)
    |> elem(0)
  end

  @doc "Lists running processes (cross-platform via `ps`)."
  @spec ps(keyword()) :: {:ok, [map()]} | {:error, term()}
  def ps(opts \\ []) do
    case OS.type() do
      :linux -> ps_linux(opts)
      :macos -> ps_macos(opts)
      :windows -> ps_windows(opts)
      _ -> {:error, :unsupported_os}
    end
  end

  @doc "Sends a signal to a process by PID."
  @spec kill(non_neg_integer(), atom()) :: :ok | {:error, term()}
  def kill(pid, signal \\ :term) do
    sig = signal_to_int(signal)

    case OS.type() do
      os when os in [:linux, :macos] ->
        try do
          {_out, exit_code} =
            System.cmd("kill", ["-#{sig}", to_string(pid)], stderr_to_stdout: true)

          case exit_code do
            0 -> :ok
            _ -> {:error, "kill signal #{sig} for pid #{pid} failed"}
          end
        catch
          e -> {:error, inspect(e)}
        end

      :windows ->
        try do
          {_out, exit_code} =
            System.cmd("taskkill", ["/PID", to_string(pid), "/F"], stderr_to_stdout: true)

          case exit_code do
            0 -> :ok
            _ -> {:error, "taskkill for pid #{pid} failed"}
          end
        catch
          e -> {:error, inspect(e)}
        end

      _ ->
        {:error, :unsupported_os}
    end
  end

  @doc "Lists files opened by a process (lsof wrapper). Linux/macOS only."
  @spec lsof(non_neg_integer()) :: {:ok, [String.t()]} | {:error, term()}
  def lsof(pid) do
    {output, exit_code} = System.cmd("lsof", ["-p", to_string(pid)], stderr_to_stdout: true)

    case exit_code do
      0 ->
        lines = output |> String.split("\n") |> Enum.drop(1) |> Enum.reject(&(&1 == ""))
        {:ok, lines}

      _ ->
        {:error, output}
    end
  rescue
    e -> {:error, inspect(e)}
  end

  @doc "Lists processes using a specific file or port (fuser wrapper)."
  @spec fuser(String.t()) :: {:ok, [non_neg_integer()]} | {:error, term()}
  def fuser(target) do
    {output, exit_code} = System.cmd("fuser", [target], stderr_to_stdout: true)

    case exit_code do
      0 ->
        pids = output |> String.split() |> Enum.map(&String.to_integer/1)
        {:ok, pids}

      _ ->
        {:error, output}
    end
  rescue
    e -> {:error, inspect(e)}
  end

  @doc "Shows recent logs for a process via journalctl (Linux systemd) or log (macOS)."
  @spec logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def logs(service, opts \\ []) do
    lines = Keyword.get(opts, :lines, 50)

    case OS.type() do
      :linux ->
        try do
          {out, exit_code} =
            System.cmd(
              "journalctl",
              ["-u", service, "-n", to_string(lines), "--no-pager"],
              stderr_to_stdout: true
            )

          case exit_code do
            0 -> {:ok, String.trim(out)}
            _ -> {:error, String.trim(out)}
          end
        catch
          e -> {:error, inspect(e)}
        end

      :macos ->
        try do
          # Escape single quotes in the service name to prevent predicate injection
          safe_service = String.replace(service, "'", "'\\''")

          {out, exit_code} =
            System.cmd(
              "log",
              [
                "show",
                "--predicate",
                "process == '#{safe_service}'",
                "--last",
                "#{lines}m"
              ],
              stderr_to_stdout: true
            )

          case exit_code do
            0 -> {:ok, String.trim(out)}
            _ -> {:error, String.trim(out)}
          end
        catch
          e -> {:error, inspect(e)}
        end

      _ ->
        {:error, :unsupported_os}
    end
  end

  # ── Private ────────────────────────────────────────────────────────

  defp ps_linux(_opts) do
    {output, exit_code} =
      System.cmd(
        "ps",
        ["-eo", "pid,ppid,user,%cpu,%mem,comm", "--no-headers"],
        stderr_to_stdout: true
      )

    case exit_code do
      0 -> {:ok, parse_ps_output(output)}
      _ -> {:error, output}
    end
  rescue
    e -> {:error, inspect(e)}
  end

  defp ps_macos(_opts) do
    {output, exit_code} =
      System.cmd(
        "ps",
        ["-eo", "pid,ppid,user,%cpu,%mem,comm", "-r"],
        stderr_to_stdout: true
      )

    case exit_code do
      0 -> {:ok, parse_ps_output(output)}
      _ -> {:error, output}
    end
  rescue
    e -> {:error, inspect(e)}
  end

  defp ps_windows(_opts) do
    {output, exit_code} =
      System.cmd("tasklist", ["/FO", "CSV", "/NH"], stderr_to_stdout: true)

    case exit_code do
      0 -> {:ok, parse_tasklist(output)}
      _ -> {:error, output}
    end
  rescue
    e -> {:error, inspect(e)}
  end

  defp parse_ps_output(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      parts = String.split(line, ~r/\s+/, parts: 6)

      %{
        pid: String.to_integer(Enum.at(parts, 0)),
        ppid: String.to_integer(Enum.at(parts, 1)),
        user: Enum.at(parts, 2),
        cpu: String.to_float(Enum.at(parts, 3)),
        mem: String.to_float(Enum.at(parts, 4)),
        command: Enum.at(parts, 5)
      }
    end)
  end

  defp parse_tasklist(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim(&1, "\""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      [name, pid, _session, _session_num, mem] = String.split(line, "\",\"")

      %{
        pid: String.to_integer(pid),
        mem: mem,
        command: String.trim(name, "\"")
      }
    end)
  end

  defp signal_to_int(:term), do: 15
  defp signal_to_int(:kill), do: 9
  defp signal_to_int(:hup), do: 1
  defp signal_to_int(:int), do: 2
  defp signal_to_int(:quit), do: 3
  defp signal_to_int(:usr1), do: 10
  defp signal_to_int(:usr2), do: 12
  defp signal_to_int(:stop), do: 19
  defp signal_to_int(:cont), do: 18
  defp signal_to_int(other) when is_integer(other), do: other
end
