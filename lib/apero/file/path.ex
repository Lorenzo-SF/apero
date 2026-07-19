defmodule Apero.File.Path do
  @moduledoc """
  Path operations: directory checks, glob, copy, move, delete, read, write.

  These functions are exposed via `Apero.File.*` delegates. You normally call them
  through `Apero.File` rather than directly.
  """

  @doc false
  @spec dir?(binary()) :: boolean()
  def dir?(path), do: File.dir?(path)

  @doc false
  @spec file?(binary()) :: boolean()
  def file?(path), do: File.regular?(path)

  @doc false
  @spec exists?(binary()) :: boolean()
  def exists?(path), do: File.exists?(path)

  @doc false
  @spec ensure_dir(binary()) :: :ok | {:error, File.posix()}
  def ensure_dir(path), do: File.mkdir_p(path)

  @doc false
  @spec symlink(binary(), binary()) :: :ok | {:error, binary()}
  def symlink(target, link_path) do
    case File.ln_s(target, link_path) do
      :ok -> :ok
      {:error, reason} -> {:error, "Cannot create symlink #{link_path} → #{target}: #{reason}"}
    end
  end

  @doc false
  @spec copy(binary(), binary()) :: {:ok, non_neg_integer()} | {:error, binary()}
  def copy(source, dest) do
    with :ok <- ensure_dir(Path.dirname(dest)),
         {:ok, bytes} <- File.copy(source, dest) do
      {:ok, bytes}
    else
      {:error, reason} -> {:error, "Cannot copy #{source} to #{dest}: #{reason}"}
    end
  end

  @doc false
  @spec copy_dir(binary(), binary()) :: :ok | {:error, binary()}
  def copy_dir(source, dest) do
    case File.cp_r(source, dest) do
      {:ok, _} -> :ok
      {:error, reason, file} -> {:error, "Cannot copy #{source} to #{dest}: #{reason} (#{file})"}
    end
  end

  @doc false
  @spec move(binary(), binary()) :: :ok | {:error, binary()}
  def move(source, dest) do
    with :ok <- ensure_dir(Path.dirname(dest)) do
      case File.rename(source, dest) do
        :ok ->
          :ok

        {:error, :exdev} ->
          move_cross_device(source, dest)

        {:error, reason} ->
          {:error, "Cannot move #{source} to #{dest}: #{reason}"}
      end
    end
  end

  defp move_cross_device(source, dest) do
    with {:ok, _} <- File.copy(source, dest),
         :ok <- File.rm(source) do
      :ok
    else
      {:error, reason} -> {:error, "Cannot move #{source} to #{dest}: #{reason}"}
    end
  end

  @doc false
  @spec delete(binary()) :: :ok | {:error, binary()}
  def delete(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, "Cannot delete #{path}: #{reason}"}
    end
  end

  @doc false
  @spec delete_dir(binary()) :: :ok | {:error, binary()}
  def delete_dir(path) do
    case File.rm_rf(path) do
      {:ok, _} -> :ok
      {:error, reason, file} -> {:error, "Cannot delete #{path}: #{reason} (#{file})"}
    end
  end

  @doc false
  @spec glob(binary(), binary(), keyword()) :: [binary()]
  def glob(dir, pattern \\ "*", opts \\ []) do
    recursive = Keyword.get(opts, :recursive, false)
    base = if recursive, do: Path.join([dir, "**", pattern]), else: Path.join(dir, pattern)
    Path.wildcard(base)
  end

  @doc false
  @spec extension(binary()) :: binary()
  def extension(path), do: Path.extname(path)

  @doc false
  @spec basename(binary()) :: binary()
  def basename(path) do
    ext = Path.extname(path)
    path |> Path.basename() |> String.replace_suffix(ext, "")
  end

  @doc false
  @spec expand(binary()) :: binary()
  def expand(path), do: Path.expand(path)

  @doc false
  @spec size(binary()) :: {:ok, non_neg_integer()} | {:error, File.posix()}
  def size(path) do
    case File.stat(path) do
      {:ok, %{size: s}} -> {:ok, s}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  @spec mtime(binary()) :: {:ok, NaiveDateTime.t()} | {:error, term()}
  def mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: ts}} ->
        case DateTime.from_unix(ts) do
          {:ok, dt} -> {:ok, DateTime.to_naive(dt)}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec write(binary(), iodata()) :: :ok | {:error, binary()}
  def write(path, content) do
    with :ok <- ensure_dir(Path.dirname(path)) do
      case File.write(path, content) do
        :ok -> :ok
        {:error, reason} -> {:error, "Cannot write #{path}: #{reason}"}
      end
    end
  end

  @doc false
  @spec read(binary()) :: {:ok, binary()} | {:error, binary()}
  def read(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, "Cannot read #{path}: #{reason}"}
    end
  end

  @doc false
  @spec read_lines(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def read_lines(path) do
    case File.read(path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))

        {:ok, lines}

      {:error, reason} ->
        {:error, "Cannot read #{path}: #{reason}"}
    end
  end
end
