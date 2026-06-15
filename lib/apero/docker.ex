defmodule Apero.Docker do
  @moduledoc """
  Docker / Podman container lifecycle management.

  Detects the available container runtime (Docker or Podman) and provides
  a unified interface for container and compose operations.

  ## Container detection

  Use `runtime/0` to detect the available runtime, or set the `RUNTIME`
  environment variable to override (`docker` or `podman`).
  """

  alias Apero.OS

  @type runtime :: :docker | :podman

  @doc "Detects the available container runtime."
  @spec runtime() :: runtime() | :none
  def runtime do
    env = System.get_env("CONTAINER_RUNTIME")

    cond do
      env == "podman" -> :podman
      env == "docker" -> :docker
      System.find_executable("podman") -> :podman
      System.find_executable("docker") -> :docker
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

    try do
      case System.cmd(to_string(rt), ["compose", "ps"], cd: cd, stderr_to_stdout: true) do
        {out, 0} -> {:ok, String.trim(out)}
        {err, _} -> {:error, String.trim(err)}
      end
    rescue
      e -> {:error, inspect(e)}
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

    try do
      case System.cmd(to_string(rt), ["compose", "exec", service | command],
             cd: cd,
             stderr_to_stdout: true
           ) do
        {out, 0} -> {:ok, String.trim(out)}
        {err, _} -> {:error, String.trim(err)}
      end
    rescue
      e -> {:error, inspect(e)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Volume operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Creates a volume."
  @spec volume_create(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_create(name, opts \\ []) do
    rt = runtime()
    run_cmd(rt, ["volume", "create", name], opts)
  end

  @doc "Lists volumes."
  @spec volume_list(keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_list(opts \\ []) do
    rt = runtime()
    run_cmd(rt, ["volume", "ls"], opts)
  end

  @doc "Removes a volume."
  @spec volume_remove(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_remove(name, opts \\ []) do
    rt = runtime()
    run_cmd(rt, ["volume", "rm", name], opts)
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Network operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Creates a network."
  @spec network_create(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_create(name, opts \\ []) do
    rt = runtime()
    run_cmd(rt, ["network", "create", name], opts)
  end

  @doc "Lists networks."
  @spec network_list(keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_list(opts \\ []) do
    rt = runtime()
    run_cmd(rt, ["network", "ls"], opts)
  end

  @doc "Removes a network."
  @spec network_remove(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_remove(name, opts \\ []) do
    rt = runtime()
    run_cmd(rt, ["network", "rm", name], opts)
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Private
  # ═══════════════════════════════════════════════════════════════════════

  defp compose(command, extra_args, opts) do
    rt = runtime()
    cd = Keyword.get(opts, :cd, ".")

    try do
      case System.cmd(to_string(rt), ["compose", command | extra_args],
             cd: cd,
             stderr_to_stdout: true
           ) do
        {out, 0} -> {:ok, String.trim(out)}
        {err, _} -> {:error, String.trim(err)}
      end
    rescue
      e -> {:error, inspect(e)}
    end
  end

  defp run_cmd(rt, args, opts) when is_list(args) do
    cd = Keyword.get(opts, :cd, ".")

    try do
      case System.cmd(to_string(rt), args, cd: cd, stderr_to_stdout: true) do
        {out, 0} -> {:ok, String.trim(out)}
        {err, _} -> {:error, String.trim(err)}
      end
    rescue
      e -> {:error, inspect(e)}
    end
  end
end
