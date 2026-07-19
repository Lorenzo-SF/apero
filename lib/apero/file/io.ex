defmodule Apero.File.IO do
  @moduledoc """
  I/O operations: atomic writes, checksums, temporary resources, file locking.

  These functions are exposed via `Apero.File.*` delegates. You normally call them
  through `Apero.File` rather than directly.

  > Only pure I/O operations remain in Apero v3.0.0.
  > Shell-based I/O (`Trebejo.File.IO.disk_usage/1`) moved to `Trebejo.File.IO`.
  """

  @doc false
  @spec atomic_write(binary(), iodata()) :: :ok | {:error, binary()}
  def atomic_write(path, content) do
    dir = Path.dirname(path)
    tmp = Path.join(dir, ".apero_tmp_#{:erlang.unique_integer([:positive])}")

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(tmp, content),
         :ok <- commit_atomic_write(tmp, path) do
      :ok
    else
      {:error, reason} ->
        File.rm(tmp)
        {:error, "atomic_write failed for #{path}: #{reason}"}
    end
  end

  defp commit_atomic_write(tmp, path) do
    case File.rename(tmp, path) do
      :ok ->
        :ok

      {:error, :exdev} ->
        case File.copy(tmp, path) do
          {:ok, _bytes} ->
            File.rm(tmp)
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @dialyzer {:nowarn_function, {:checksum, 1}}
  @dialyzer {:nowarn_function, {:checksum, 2}}

  @doc false
  @spec checksum(binary(), :sha256 | :sha512 | :md5 | :sha) ::
          {:ok, binary()} | {:error, binary()}
  def checksum(path, algo \\ :sha256) do
    if File.exists?(path) do
      digest =
        path
        |> File.stream!([], 65_536)
        |> Enum.reduce(:crypto.hash_init(algo), fn chunk, ctx ->
          :crypto.hash_update(ctx, chunk)
        end)
        |> :crypto.hash_final()
        |> Base.encode16(case: :lower)

      {:ok, digest}
    else
      {:error, "file not found: #{path}"}
    end
  end

  @doc false
  @spec checksum_many([binary()], :sha256 | :sha512 | :md5 | :sha) ::
          %{binary() => {:ok, binary()} | {:error, binary()}}
  def checksum_many(paths, algo \\ :sha256) when is_list(paths) do
    paths
    |> Task.async_stream(
      fn p -> {p, checksum(p, algo)} end,
      max_concurrency: min(length(paths), 4),
      ordered: true
    )
    |> Enum.reduce(%{}, fn
      {:ok, {path, {:ok, result}}}, acc ->
        Map.put(acc, path, {:ok, result})

      {:ok, {path, {:error, reason}}}, acc ->
        Map.put(acc, path, {:error, reason})

      {:exit, _reason}, acc ->
        acc
    end)
  end

  @doc false
  @spec with_tmp_file(keyword(), (binary() -> any())) :: any()
  def with_tmp_file(opts \\ [], fun) when is_function(fun, 1) do
    suffix = Keyword.get(opts, :suffix, "")
    dir = Keyword.get(opts, :dir, System.tmp_dir!())
    path = Path.join(dir, "apero_tmp_#{:erlang.unique_integer([:positive])}#{suffix}")
    File.touch!(path)

    try do
      fun.(path)
    after
      File.rm(path)
    end
  end

  @doc false
  @spec with_tmp_dir(keyword(), (binary() -> any())) :: any()
  def with_tmp_dir(opts \\ [], fun) when is_function(fun, 1) do
    parent = Keyword.get(opts, :dir, System.tmp_dir!())
    dir = Path.join(parent, "apero_tmpdir_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      fun.(dir)
    after
      File.rm_rf(dir)
    end
  end

  @doc false
  @spec with_lock(binary(), keyword(), (-> any())) :: any() | {:error, :timeout}
  def with_lock(lock_path, opts \\ [], fun) when is_function(fun, 0) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 5_000)
    retry_ms = Keyword.get(opts, :retry_ms, 100)
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    acquire_lock(lock_path, deadline, retry_ms, fun)
  end

  @doc false
  @spec copy_many([{binary(), binary()}]) :: [{:ok, non_neg_integer()} | {:error, binary()}]
  def copy_many(pairs) when is_list(pairs) do
    pairs
    |> Enum.with_index()
    |> Task.async_stream(
      fn {pair, _idx} -> copy_pair(pair) end,
      max_concurrency: min(length(pairs), 8),
      ordered: false
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, inspect(reason)}
    end)
  end

  # ── Private ────────────────────────────────────────────────────────

  defp copy_pair({source, dest}) do
    dest_dir = Path.dirname(dest)

    with :ok <- File.mkdir_p(dest_dir),
         {:ok, _bytes} <- File.copy(source, dest) do
      {:ok, 0}
    else
      {:error, reason} -> {:error, "Cannot copy #{source} to #{dest}: #{reason}"}
    end
  end

  defp acquire_lock(lock_path, deadline, retry_ms, fun) do
    now = System.monotonic_time(:millisecond)

    if now > deadline do
      {:error, :timeout}
    else
      case File.open(lock_path, [:write, :exclusive]) do
        {:ok, file} ->
          try do
            fun.()
          after
            File.close(file)
            File.rm(lock_path)
          end

        {:error, :eexist} ->
          Process.sleep(retry_ms)
          acquire_lock(lock_path, deadline, retry_ms, fun)

        {:error, reason} ->
          {:error, "Cannot acquire lock #{lock_path}: #{reason}"}
      end
    end
  end
end
