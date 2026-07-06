defmodule Apero.SSH do
  @moduledoc """
  SSH wrapper for remote command execution and file transfer.

  Wraps the `ssh` and `scp` system binaries. For richer SSH support
  (key management, interactive sessions, etc.) consider a dedicated
  library like `:ssh` or `:erlexec`.

  All command execution is routed through `Arrea.Command.execute/2`
  with `validate: false`. Arguments are shell-quoted before being
  joined into the final command line so user/host/command values
  containing whitespace or shell metacharacters are safe.
  """

  alias Arrea.Command

  @default_port 22
  @default_user "root"

  @doc """
  Executes a command on a remote host via SSH.

  Returns `{:ok, output}` on success or `{:error, reason}` on failure.

  ## Options

    * `:user` — SSH user (default: `root`)
    * `:port` — SSH port (default: 22)
    * `:identity` — path to private key (default: system default)
  """
  @spec exec(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def exec(host, command, opts \\ []) do
    user = Keyword.get(opts, :user, @default_user)
    port = Keyword.get(opts, :port, @default_port)
    key = Keyword.get(opts, :identity, nil)

    args = build_ssh_args(key, port, user, host, command)
    cmd = ["ssh" | Enum.map(args, &shell_quote/1)] |> Enum.join(" ")

    case Command.execute(cmd, validate: false) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:ssh_failed, code, output}}
    end
  end

  @doc """
  Copies a local file to a remote host via SCP.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec scp(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def scp(local, remote_host, remote_path, opts \\ []) do
    user = Keyword.get(opts, :user, @default_user)
    port = Keyword.get(opts, :port, @default_port)
    key = Keyword.get(opts, :identity, nil)

    args = build_scp_args(key, port, local, user, remote_host, remote_path)
    cmd = ["scp" | Enum.map(args, &shell_quote/1)] |> Enum.join(" ")

    case Command.execute(cmd, validate: false) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:scp_failed, code, output}}
    end
  end

  defp build_ssh_args(key, port, user, host, command) do
    base = [
      "-p",
      to_string(port),
      "-o",
      "BatchMode=yes",
      "-o",
      "StrictHostKeyChecking=accept-new",
      "#{user}@#{host}",
      command
    ]

    if key, do: ["-i", key] ++ base, else: base
  end

  defp build_scp_args(key, port, local, user, host, path) do
    base = ["-P", to_string(port), local, "#{user}@#{host}:#{path}"]
    if key, do: ["-i", key] ++ base, else: base
  end

  # Single-quote a string for safe inclusion in a POSIX shell command
  # line. Replaces internal single quotes with the standard
  # `'\\''` close-then-reopen pattern. Same approach as Apero.Git.Local,
  # Apero.Docker and Apero.Kubernetes (just landed in this branch).
  defp shell_quote(str) when is_binary(str) do
    escaped = String.replace(str, "'", "'\\''")
    "'#{escaped}'"
  end
end
