defmodule Apero.Kubernetes do
  @moduledoc """
  Thin wrapper over `kubectl` for common operations.

  For richer Kubernetes integration (CRUD, watchers, label selectors)
  consider using `:k8s` or the official client libraries.
  """

  @doc """
  Checks if `kubectl` is available and the cluster responds.
  """
  @spec available?() :: boolean()
  def available? do
    case System.cmd("kubectl", ["cluster-info"], stderr_to_stdout: true) do
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
    kubectl(["get", "pods", "-n", namespace, "-o", output])
  end

  @doc """
  Applies a Kubernetes manifest YAML.
  """
  @spec apply(String.t(), keyword()) :: :ok | {:error, term()}
  def apply(manifest_path, _opts \\ []) do
    case System.cmd("kubectl", ["apply", "-f", manifest_path], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:apply_failed, code, output}}
    end
  end

  @doc """
  Deletes a Kubernetes resource by name and kind.
  """
  @spec delete(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete(kind, name, namespace, _opts \\ []) do
    case System.cmd("kubectl", ["delete", kind, name, "-n", namespace], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:delete_failed, code, output}}
    end
  end

  defp kubectl(args) do
    case System.cmd("kubectl", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:kubectl_failed, code, output}}
    end
  end
end
