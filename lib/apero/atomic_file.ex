defmodule Apero.Atomic.File do
  @moduledoc """
  Atomic file operations: write to a temp file, then rename over the
  target.

  A reader never observes a partially-written file, because the rename
  is atomic within a filesystem. Used by config managers (delfos phase 4)
  and anything that needs crash-safe writes.

  ## Example

      iex> path = Path.join(System.tmp_dir(), "apero-atomic-#{System.unique_integer([:positive])}.txt")
      iex> Apero.Atomic.File.write(path, "hello")
      :ok
      iex> Apero.Atomic.File.replace(path, fn content -> {:ok, String.upcase(content)} end)
      :ok
      iex> File.read!(path)
      "HELLO"
  """

  @doc """
  Writes `iodata` to `path` atomically.

  The data is first written to a temp file in the same directory as
  `path` (so the final rename stays on one filesystem), then renamed over
  `path`. If anything fails, the temp file is removed and no partial
  content is ever visible at `path`.

  ## Options

    - `fsync: boolean()` — fsync the temp file before renaming
      (default: `false`)
    - `tmp_dir: binary()` — override the temp directory (must be on the
      same filesystem as `path`; default: the directory of `path`)
    - `retry_eagain: pos_integer()` — how many times to retry when the OS
      reports `:eagain` (default: 3)

  ## Examples

      iex> path = Path.join(System.tmp_dir(), "apero-atomic-#{System.unique_integer([:positive])}.txt")
      iex> Apero.Atomic.File.write(path, "hello", fsync: true)
      :ok
  """
  @spec write(binary(), iodata(), keyword()) :: :ok | {:error, term()}
  def write(path, iodata, opts \\ []) do
    fsync? = Keyword.get(opts, :fsync, false)
    tmp_dir = Keyword.get(opts, :tmp_dir, Path.dirname(path))
    retry_eagain = Keyword.get(opts, :retry_eagain, 3)

    tmp_path = Path.join(tmp_dir, "#{Path.basename(path)}.tmp-#{:rand.uniform(1_000_000)}")

    case do_write(tmp_path, path, iodata, fsync?) do
      {:error, :eagain} when retry_eagain > 0 ->
        Process.sleep(10)
        write(path, iodata, Keyword.put(opts, :retry_eagain, retry_eagain - 1))

      other ->
        other
    end
  end

  @doc """
  Reads `path`, applies `fun/1`, and writes the result atomically.

  `fun` receives the current file content and must return
  `{:ok, new_content}` or `{:error, reason}`. When `fun` returns an
  error, the original file is left untouched.

  ## Examples

      iex> path = Path.join(System.tmp_dir(), "apero-atomic-#{System.unique_integer([:positive])}.txt")
      iex> Apero.Atomic.File.write(path, "hello")
      :ok
      iex> Apero.Atomic.File.replace(path, fn content -> {:ok, content <> "!"} end)
      :ok
      iex> File.read!(path)
      "hello!"
  """
  @spec replace(binary(), (binary() -> {:ok, iodata()} | {:error, term()}), keyword()) ::
          :ok | {:error, term()}
  def replace(path, fun, opts \\ []) do
    case File.read(path) do
      {:ok, content} ->
        case fun.(content) do
          {:ok, new_content} -> write(path, new_content, opts)
          {:error, _reason} = error -> error
        end

      {:error, _reason} = error ->
        error
    end
  end

  # -- private ----------------------------------------------------------

  defp do_write(tmp_path, path, iodata, fsync?) do
    with {:ok, io} <- File.open(tmp_path, [:write, :binary]) do
      try do
        with :ok <- IO.binwrite(io, iodata),
             :ok <- maybe_sync(io, fsync?) do
          case File.rename(tmp_path, path) do
            :ok -> :ok
            {:error, _reason} = error -> error
          end
        end
      after
        File.close(io)
      end
    end
    |> cleanup_on_error(tmp_path)
  end

  defp maybe_sync(_io, false), do: :ok

  defp maybe_sync(io, true) do
    case :file.sync(io) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Remove the temp file unless the rename already consumed it.
  defp cleanup_on_error(:ok, _tmp_path), do: :ok

  defp cleanup_on_error({:error, _reason} = error, tmp_path) do
    _ = File.rm(tmp_path)
    error
  end
end
