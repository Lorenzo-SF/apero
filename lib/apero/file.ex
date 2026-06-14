defmodule Apero.File do
  @moduledoc """
  File system utilities — file ops, path operations, atomic writes, temp resources, locking, watching.

  Provides domain-specific tools for file and filesystem operations behind a
  consistent `{:ok, result} | {:error, reason}` interface.

  ## Submodules

    * `Apero.File.IO` — I/O operations (atomic writes, checksums, temp resources, locking)
    * `Apero.File.Path` — path operations (copy, move, delete, glob, etc.)
    * `Apero.File.Tree` — ASCII tree generation and printing
    * `Apero.File.Watcher` — file system watching via GenServer

  ## Backward Compatibility

  `Apero.VFS` is an alias for `Apero.File` for backward compatibility.

  ## Security note

  `atomic_write/2` always creates the temp file in the same directory as the
  target to guarantee `rename(2)` atomicity (cross-device renames fall back
  to copy+delete).
  """

  # ── Path operations (delegated to Apero.File.Path) ──────────────────────

  @doc """
  Returns `true` if the given path is an existing directory.
  """
  @spec dir?(binary()) :: boolean()
  defdelegate dir?(path), to: Apero.File.Path

  @doc """
  Returns `true` if the given path is an existing regular file.
  """
  @spec file?(binary()) :: boolean()
  defdelegate file?(path), to: Apero.File.Path

  @doc """
  Returns `true` if the given path exists (file, directory or symlink).
  """
  @spec exists?(binary()) :: boolean()
  defdelegate exists?(path), to: Apero.File.Path

  @doc """
  Creates the directory and all parents. Idempotent.
  """
  @spec ensure_dir(binary()) :: :ok | {:error, File.posix()}
  defdelegate ensure_dir(path), to: Apero.File.Path

  @doc """
  Creates a symbolic link at `link_path` pointing to `target`.
  """
  @spec symlink(binary(), binary()) :: :ok | {:error, binary()}
  defdelegate symlink(target, link_path), to: Apero.File.Path

  @doc """
  Copies `source` to `dest`. Creates parent directories as needed.
  Returns `{:ok, bytes_copied}`.
  """
  @spec copy(binary(), binary()) :: {:ok, non_neg_integer()} | {:error, binary()}
  defdelegate copy(source, dest), to: Apero.File.Path

  @doc """
  Recursively copies a directory from `source` to `dest`.
  """
  @spec copy_dir(binary(), binary()) :: :ok | {:error, binary()}
  defdelegate copy_dir(source, dest), to: Apero.File.Path

  @doc """
  Moves `source` to `dest`. Uses rename when possible, falls back to copy+delete
  on cross-device moves.
  """
  @spec move(binary(), binary()) :: :ok | {:error, binary()}
  defdelegate move(source, dest), to: Apero.File.Path

  @doc """
  Deletes a file. Returns `:ok` even if the file did not exist.
  """
  @spec delete(binary()) :: :ok | {:error, binary()}
  defdelegate delete(path), to: Apero.File.Path

  @doc """
  Recursively deletes a directory and all its contents.
  """
  @spec delete_dir(binary()) :: :ok | {:error, binary()}
  defdelegate delete_dir(path), to: Apero.File.Path

  @doc """
  Lists files matching a glob pattern in `dir`.

  ## Options

    * `:recursive` — recurse into subdirectories (default: `false`)
  """
  @spec glob(binary(), binary(), keyword()) :: [binary()]
  defdelegate glob(dir, pattern \\ "*", opts \\ []), to: Apero.File.Path

  @doc """
  Returns the extension of a file path.

  ## Examples

      iex> Apero.File.extension("archive.tar.gz")
      ".gz"

  """
  @spec extension(binary()) :: binary()
  defdelegate extension(path), to: Apero.File.Path

  @doc """
  Returns the filename without extension.

  ## Examples

      iex> Apero.File.basename("path/to/file.ex")
      "file"

  """
  @spec basename(binary()) :: binary()
  defdelegate basename(path), to: Apero.File.Path

  @doc """
  Expands `~` and relative path segments to an absolute path.
  """
  @spec expand(binary()) :: binary()
  defdelegate expand(path), to: Apero.File.Path

  @doc """
  Returns the file size in bytes.
  """
  @spec size(binary()) :: {:ok, non_neg_integer()} | {:error, File.posix()}
  defdelegate size(path), to: Apero.File.Path

  @doc """
  Returns the last modification time of a file as a `NaiveDateTime`.
  """
  @spec mtime(binary()) :: {:ok, NaiveDateTime.t()} | {:error, File.posix()}
  defdelegate mtime(path), to: Apero.File.Path

  @doc """
  Writes text to a file, creating parent directories as needed.
  """
  @spec write(binary(), iodata()) :: :ok | {:error, binary()}
  defdelegate write(path, content), to: Apero.File.Path

  @doc """
  Reads a text file and returns its contents.
  """
  @spec read(binary()) :: {:ok, binary()} | {:error, binary()}
  defdelegate read(path), to: Apero.File.Path

  @doc """
  Reads all non-empty, non-comment lines from a file.

  Lines starting with `#` and blank lines are removed. Content is trimmed.
  """
  @spec read_lines(binary()) :: {:ok, [binary()]} | {:error, binary()}
  defdelegate read_lines(path), to: Apero.File.Path

  # ── I/O operations (delegated to Apero.File.IO) ─────────────────────────

  @doc """
  Writes `content` to `path` atomically using a temp-file + rename.

  The temp file is created in the same directory as `path` to ensure the
  rename is atomic on POSIX systems. Parent directories are created as needed.

  ## Examples

      iex> path = Path.join(System.tmp_dir!(), "apero_atomic_test.txt")
      iex> :ok = Apero.File.atomic_write(path, "hello")
      iex> File.read!(path)
      "hello"
      iex> File.rm!(path)
      :ok

  """
  @spec atomic_write(binary(), iodata()) :: :ok | {:error, binary()}
  defdelegate atomic_write(path, content), to: Apero.File.IO

  @doc """
  Computes the checksum of a file by streaming its contents in 64KB chunks.
  Never loads the entire file into memory.

  Supported algorithms: `:sha256`, `:sha512`, `:md5`, `:sha`.
  Returns the lowercase hex-encoded digest.

  ## Examples

      iex> path = Path.join(System.tmp_dir!(), "apero_cs_test.bin")
      iex> File.write!(path, "hello")
      iex> {:ok, digest} = Apero.File.checksum(path, :sha256)
      iex> String.length(digest)
      64
      iex> File.rm!(path)
      :ok

  """
  @spec checksum(binary(), :sha256 | :sha512 | :md5 | :sha) ::
          {:ok, binary()} | {:error, binary()}
  defdelegate checksum(path, algo \\ :sha256), to: Apero.File.IO

  @doc """
  Computes checksums for multiple files in parallel.

  Returns a map of `path => {:ok, digest} | {:error, reason}`.
  """
  @spec checksum_many([binary()], :sha256 | :sha512 | :md5 | :sha) ::
          %{binary() => {:ok, binary()} | {:error, binary()}}
  defdelegate checksum_many(paths, algo \\ :sha256), to: Apero.File.IO

  @doc """
  Creates a temporary file, yields its path to `fun`, then deletes it.
  The file is deleted even when `fun` raises.

  ## Options

    * `:suffix` — file extension suffix (default: `""`)
    * `:dir` — parent directory (default: `System.tmp_dir!/0`)
  """
  @spec with_tmp_file(keyword(), (binary() -> any())) :: any()
  defdelegate with_tmp_file(opts \\ [], fun), to: Apero.File.IO

  @doc """
  Creates a temporary directory, yields its path to `fun`, then deletes it.
  The directory is deleted even when `fun` raises.
  """
  @spec with_tmp_dir(keyword(), (binary() -> any())) :: any()
  defdelegate with_tmp_dir(opts \\ [], fun), to: Apero.File.IO

  @doc """
  Acquires an advisory lock on `lock_path`, runs `fun`, then releases it.

  Retries on `EEXIST` until timeout. Returns `{:error, :timeout}` if the
  lock cannot be acquired within the deadline.

  ## Options

    * `:timeout_ms` — how long to wait in ms (default: `5_000`)
    * `:retry_ms` — poll interval in ms (default: `100`)
  """
  @spec with_lock(binary(), keyword(), (-> any())) :: any() | {:error, :timeout}
  defdelegate with_lock(lock_path, opts \\ [], fun), to: Apero.File.IO

  @doc """
  Returns disk usage information for the filesystem containing `path`.

  Returns a map with `:total_mb`, `:used_mb`, `:free_mb`, `:use_pct`.
  Only supported on Unix-like systems.
  """
  @spec disk_usage(binary()) :: {:ok, map()} | {:error, binary()}
  defdelegate disk_usage(path \\ "/"), to: Apero.File.IO

  @doc """
  Copies multiple files in parallel.

  Each element of `pairs` is a `{source, dest}` tuple.
  Returns `[{:ok, bytes} | {:error, reason}]` in the same order.
  """
  @spec copy_many([{binary(), binary()}]) :: [{:ok, non_neg_integer()} | {:error, binary()}]
  defdelegate copy_many(pairs), to: Apero.File.IO

  # ── Tree operations (delegated to Apero.File.Tree) ──────────────────────

  @doc """
  Generates a visual ASCII tree from a list of file paths.

  Returns a printable string with `├─` and `└─` connectors.
  The last item at each level uses `└─`, all others use `├─`.

  ## Examples

      iex> Apero.File.generate_tree(["a"])
      "└─ a"

  """
  @spec generate_tree([binary()]) :: binary()
  defdelegate generate_tree(paths), to: Apero.File.Tree

  @doc """
  Prints an ASCII directory tree of `path` to stdout.
  """
  @spec print_tree(binary()) :: :ok
  defdelegate print_tree(path), to: Apero.File.Tree

  # ── File watcher (stays in File) ────────────────────────────────────────

  @doc """
  Starts watching `dirs` for file system changes.

  Calls `callback` with a list of `{path, events}` tuples after each
  debounce window.

  ## Options

    * `:debounce_ms` — debounce delay in ms (default: `100`)
    * `:name` — optional name for the watcher process

  Returns `{:ok, pid}`.
  """
  @spec watch([binary()], ([{binary(), [atom()]}] -> any()), keyword()) ::
          {:ok, pid()} | {:error, term()}
  def watch(dirs, callback, opts \\ []) when is_list(dirs) and is_function(callback, 1) do
    watcher_opts = %{
      dirs: dirs,
      callback: callback,
      debounce_ms: Keyword.get(opts, :debounce_ms, 100),
      name: Keyword.get(opts, :name)
    }

    child_spec = {Apero.File.Watcher, watcher_opts}

    case DynamicSupervisor.start_child(Arrea.WorkerSupervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:ok, pid, _info} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      :ignore -> {:error, :ignore}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stops a file watcher by PID.
  """
  @spec unwatch(pid()) :: :ok
  def unwatch(pid) when is_pid(pid) do
    GenServer.stop(pid, :normal)
    :ok
  end
end
