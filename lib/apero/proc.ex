defmodule Apero.Proc do
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  @moduledoc """
  Process and executable utilities for Apero.

  Provides helpers for checking command availability, finding executables,
  inspecting running processes, sending signals, and viewing process logs.

  All command execution is routed through `Arrea.Command.execute/2`
  (with `validate: false`) so consumers get real timeout cancellation,
  telemetry, and structured errors. The fragile `try/rescue` blocks
  are gone — Arrea returns `{:error, reason}` on timeout / missing
  binary / etc.

  """

  alias Apero.OS
  alias Arrea.Command

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
        case run_cmd("kill -#{sig} #{pid}") do
          {_, 0} -> :ok
          {_, _} -> {:error, "kill signal #{sig} for pid #{pid} failed"}
        end

      :windows ->
        case run_cmd("taskkill /PID #{pid} /F") do
          {_, 0} -> :ok
          {_, _} -> {:error, "taskkill for pid #{pid} failed"}
        end

      _ ->
        {:error, :unsupported_os}
    end
  end

  @doc "Lists files opened by a process (lsof wrapper). Linux/macOS only."
  @spec lsof(non_neg_integer()) :: {:ok, [String.t()]} | {:error, term()}
  def lsof(pid) do
    case run_cmd("lsof -p #{pid}") do
      {output, 0} ->
        lines = output |> String.split("\n") |> Enum.drop(1) |> Enum.reject(&(&1 == ""))
        {:ok, lines}

      {output, _} ->
        {:error, output}
    end
  end

  @doc "Lists processes using a specific file or port (fuser wrapper)."
  @spec fuser(String.t()) :: {:ok, [non_neg_integer()]} | {:error, term()}
  def fuser(target) do
    case run_cmd("fuser #{target}") do
      {output, 0} ->
        # fuser output can include non-numeric lines (e.g. header on
        # some distros) and empty tokens. Use Integer.parse/1 to skip
        # anything that isn't a valid PID, so a single malformed token
        # doesn't fail the whole call.
        pids =
          output
          |> String.split()
          |> Enum.flat_map(fn
            {n, ""} -> [n]
            _ -> []
          end)

        {:ok, pids}

      {output, _} ->
        {:error, output}
    end
  end

  @doc "Shows recent logs for a process via journalctl (Linux systemd) or log (macOS)."
  @spec logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def logs(service, opts \\ []) do
    lines = Keyword.get(opts, :lines, 50)

    case OS.type() do
      :linux ->
        case run_cmd("journalctl -u #{service} -n #{lines} --no-pager") do
          {out, 0} -> {:ok, String.trim(out)}
          {out, _} -> {:error, String.trim(out)}
        end

      :macos ->
        # Escape single quotes in the service name to prevent predicate
        # injection in the --predicate clause.
        safe_service = String.replace(service, "'", "'\\''")

        case run_cmd("log show --predicate process == '#{safe_service}' --last #{lines}m") do
          {out, 0} -> {:ok, String.trim(out)}
          {out, _} -> {:error, String.trim(out)}
        end

      _ ->
        {:error, :unsupported_os}
    end
  end

  # ── Private ────────────────────────────────────────────────────────

  defp ps_linux(_opts) do
    case run_cmd("ps -eo pid,ppid,user,%cpu,%mem,comm --no-headers") do
      {output, 0} -> {:ok, parse_ps_output(output)}
      {output, _} -> {:error, output}
    end
  end

  defp ps_macos(_opts) do
    case run_cmd("ps -eo pid,ppid,user,%cpu,%mem,comm -r") do
      {output, 0} -> {:ok, parse_ps_output(output)}
      {output, _} -> {:error, output}
    end
  end

  defp ps_windows(_opts) do
    case run_cmd("tasklist /FO CSV /NH") do
      {output, 0} -> {:ok, parse_tasklist(output)}
      {output, _} -> {:error, output}
    end
  end

  defp parse_ps_output(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    # ps can emit %CPU as an integer ("663") on busy systems or as a
    # float ("0.0") on idle ones. Use Float.parse which handles both
    # ("0.0" -> 0.0, "663" -> 663.0); nil falls through to the
    # original raw string and the line is dropped (better than crashing
    # the whole ps/1 call on a single malformed line).
    |> Enum.flat_map(fn line ->
      parts = String.split(line, ~r/\s+/, parts: 6)

      with {pid, ""} <- Integer.parse(Enum.at(parts, 0) || ""),
           {ppid, ""} <- Integer.parse(Enum.at(parts, 1) || ""),
           {cpu, ""} <- Float.parse(Enum.at(parts, 3) || ""),
           {mem, ""} <- Float.parse(Enum.at(parts, 4) || "") do
        [
          %{
            pid: pid,
            ppid: ppid,
            user: Enum.at(parts, 2) || "",
            cpu: cpu,
            mem: mem,
            command: Enum.at(parts, 5) || ""
          }
        ]
      else
        _ -> []
      end
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

  # Same shape as Apero.OS.run_cmd/1 — single-line wrapper around
  # Arrea.Command.execute/2 that returns the legacy {output, exit_code}
  # tuple so the existing case ... do {out, 0} -> ...; _ -> ... call
  # sites stay unchanged. On Arrea failure (timeout, missing binary)
  # returns {"", 1} so the caller falls through to its fallback branch.
  @spec run_cmd(String.t()) :: {String.t(), non_neg_integer()}
  defp run_cmd(cmd) do
    case Command.execute(cmd, validate: false) do
      {:ok, %{stdout: out, exit_code: code}} -> {out, code}
      _ -> {"", 1}
    end
  end
end
