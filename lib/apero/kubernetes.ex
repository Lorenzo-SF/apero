defmodule Apero.Kubernetes do
  @moduledoc """
  Thin wrapper over `kubectl` for common operations.

  All `kubectl` invocations are routed through `Arrea.Command.execute/2`
  with `validate: false`. Arguments are shell-quoted before being
  joined into the final command line.

  For richer Kubernetes integration (CRUD, watchers, label selectors)
  consider using `:k8s` or the official client libraries.
  """

  alias Arrea.Command

  @doc """
  Checks if `kubectl` is available and the cluster responds.
  """
  @spec available?() :: boolean()
  def available? do
    case run(["cluster-info"]) do
      {_, 0} -> true
      _ -> false
    end
  end

  @doc """
  Lists the pods in a namespace.

  Returns `{:ok, output}` or `{:error, reason}`.
  """
  @spec pods(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def pods(namespace, opts \\ []) do
    output = Keyword.get(opts, :output, "json")
    run(["get", "pods", "-n", namespace, "-o", output])
  end

  @doc """
  Applies a Kubernetes manifest YAML.
  """
  @spec apply(String.t(), keyword()) :: :ok | {:error, term()}
  def apply(manifest_path, _opts \\ []) do
    case run(["apply", "-f", manifest_path]) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:apply_failed, code, output}}
    end
  end

  @doc """
  Deletes a Kubernetes resource by name and kind.
  """
  @spec delete(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete(kind, name, namespace, _opts \\ []) do
    case run(["delete", kind, name, "-n", namespace]) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:delete_failed, code, output}}
    end
  end

  # Routes kubectl through Arrea.Command.execute/2 with validate: false.
  # Returns the legacy {output, exit_code} tuple so the {_, 0} -> ...
  # pattern matches in the public functions above stay readable. On
  # Arrea failure (timeout, missing binary) returns {"", 1} so the
  # caller falls through to the error branch.
  defp run(args) do
    cmd = ["kubectl" | Enum.map(args, &shell_quote/1)] |> Enum.join(" ")

    case Command.execute(cmd, validate: false) do
      {:ok, %{stdout: out, exit_code: code}} -> {out, code}
      _ -> {"", 1}
    end
  end

  # Single-quote a string for safe inclusion in a POSIX shell command
  # line. Replaces internal single quotes with the standard
  # `'\\''` close-then-reopen pattern.
  defp shell_quote(str) when is_binary(str) do
    escaped = String.replace(str, "'", "'\\''")
    "'#{escaped}'"
  end
end
