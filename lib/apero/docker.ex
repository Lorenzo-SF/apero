defmodule Apero.Docker do
  @moduledoc """
  Docker / Podman container lifecycle management.

  Detects the available container runtime (Docker or Podman) and provides
  a unified interface for container and compose operations.

  All command execution is routed through `Arrea.Command.execute/2` with
  `validate: false`. Runtime is auto-detected via
  `Apero.Proc.command_exists?/1`; environment variable `CONTAINER_RUNTIME`
  (`docker` | `podman`) overrides the detection.

  ## Container detection

  Use `runtime/0` to detect the available runtime, or set the
  `CONTAINER_RUNTIME` environment variable to override.
  """

  alias Apero.OS
  alias Apero.Proc
  alias Arrea.Command

  @type runtime :: :docker | :podman

  @doc "Detects the available container runtime."
  @spec runtime() :: runtime() | :none
  def runtime do
    env = System.get_env("CONTAINER_RUNTIME")

    cond do
      env == "podman" -> :podman
      env == "docker" -> :docker
      Proc.command_exists?("podman") -> :podman
      Proc.command_exists?("docker") -> :docker
      true -> :none
    end
  end

  @doc "Returns true if running inside a container."
  @spec in_container?() :: boolean()
  def in_container? do
    OS.container?()
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Compose operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Starts services defined in docker-compose.yml."
  @spec up(keyword()) :: {:ok, binary()} | {:error, binary()}
  def up(opts \\ []), do: compose("up", ["-d"], opts)

  @doc "Stops and removes services."
  @spec down(keyword()) :: {:ok, binary()} | {:error, binary()}
  def down(opts \\ []), do: compose("down", [], opts)

  @doc "Restarts services."
  @spec restart(keyword()) :: {:ok, binary()} | {:error, binary()}
  def restart(opts \\ []), do: compose("restart", [], opts)

  @doc "Pulls images."
  @spec pull(keyword()) :: {:ok, binary()} | {:error, binary()}
  def pull(opts \\ []), do: compose("pull", [], opts)

  @doc "Builds images."
  @spec build(keyword()) :: {:ok, binary()} | {:error, binary()}
  def build(opts \\ []), do: compose("build", [], opts)

  @doc "Lists running services."
  @spec ps(keyword()) :: {:ok, binary()} | {:error, binary()}
  def ps(opts \\ []) do
    rt = runtime()
    cd = Keyword.get(opts, :cd, ".")

    case run_cmd_str(to_string(rt), ["compose", "ps"], cd: cd) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Shows logs."
  @spec logs(keyword()) :: {:ok, binary()} | {:error, binary()}
  def logs(opts \\ []), do: compose("logs", ["-f"], opts)

  @doc "Executes a command in a service container."
  @spec exec(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def exec(service, command, opts \\ []) do
    rt = runtime()
    cd = Keyword.get(opts, :cd, ".")

    case run_cmd_str(to_string(rt), ["compose", "exec", service | command], cd: cd) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Volume operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Creates a volume."
  @spec volume_create(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_create(name, opts \\ []) do
    run_cmd_str(runtime(), ["volume", "create", name], opts)
  end

  @doc "Lists volumes."
  @spec volume_list(keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_list(opts \\ []) do
    run_cmd_str(runtime(), ["volume", "ls"], opts)
  end

  @doc "Removes a volume."
  @spec volume_remove(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_remove(name, opts \\ []) do
    run_cmd_str(runtime(), ["volume", "rm", name], opts)
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Network operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Creates a network."
  @spec network_create(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_create(name, opts \\ []) do
    run_cmd_str(runtime(), ["network", "create", name], opts)
  end

  @doc "Lists networks."
  @spec network_list(keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_list(opts \\ []) do
    run_cmd_str(runtime(), ["network", "ls"], opts)
  end

  @doc "Removes a network."
  @spec network_remove(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_remove(name, opts \\ []) do
    run_cmd_str(runtime(), ["network", "rm", name], opts)
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Private
  # ═══════════════════════════════════════════════════════════════════════

  defp compose(command, extra_args, opts) do
    cd = Keyword.get(opts, :cd, ".")

    case run_cmd_str(to_string(runtime()), ["compose", command | extra_args], cd: cd) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # Builds a single command string from a runtime binary + argv list,
  # shell-quoting each argument. Routes through Arrea.Command.execute/2
  # which gives real timeout cancellation, telemetry, and structured
  # errors. Returns the legacy {output, exit_code} tuple so the
  # call sites above stay readable; on Arrea failure (timeout, missing
  # binary) returns {"", 1} so the caller falls through to the
  # error branch.
  defp run_cmd_str(runtime, args, opts) do
    quoted = Enum.map(args, &shell_quote/1)
    cmd = [runtime | quoted] |> Enum.join(" ")

    base = [validate: false, stderr_to_stdout: true]
    arity = Keyword.merge(base, opts)

    case Command.execute(cmd, arity) do
      {:ok, %{stdout: out, exit_code: code}} -> {out, code}
      _ -> {"", 1}
    end
  end

  # Single-quote a string for safe inclusion in a POSIX shell command
  # line. Replaces internal single quotes with the standard
  # `'\\''` close-then-reopen pattern. Same approach as Apero.Git.Local.
  defp shell_quote(str) when is_binary(str) do
    escaped = String.replace(str, "'", "'\\''")
    "'#{escaped}'"
  end
end
