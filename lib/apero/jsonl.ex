defmodule Apero.Jsonl do
  @moduledoc """
  JSON Lines (jsonl) file operations for streaming JSON data.

  Each line is a single JSON value (typically a map). The file is
  append-only: `write!/3` truncates and rewrites, `append!/3` adds a
  line. Readers are tolerant of corrupted or truncated trailing lines
  (e.g. after a crash mid-write) — the bad line is skipped with a
  `Logger.warning` instead of raising.

  ## Example

      iex> path = Path.join(System.tmp_dir(), "apero-jsonl-#{System.unique_integer([:positive])}.jsonl")
      iex> Apero.Jsonl.write!(path, [%{a: 1}, %{b: 2}])
      :ok
      iex> Apero.Jsonl.append!(path, %{c: 3})
      :ok
      iex> Apero.Jsonl.read_all(path)
      {:ok, [%{"a" => 1}, %{"b" => 2}, %{"c" => 3}]}
  """

  require Logger

  @doc """
  Writes a list of maps to a JSONL file, truncating any existing file.

  ## Parameters

    - `path` — path to the file
    - `list_of_maps` — list of maps to write
    - `opts` — reserved for future options (currently unused)

  Raises on write failure.

  ## Examples

      iex> path = Path.join(System.tmp_dir(), "apero-jsonl-#{System.unique_integer([:positive])}.jsonl")
      iex> Apero.Jsonl.write!(path, [%{a: 1}, %{b: 2}])
      :ok
  """
  @spec write!(binary(), [map()], keyword()) :: :ok
  def write!(path, list_of_maps, _opts \\ []) do
    content = Enum.map_join(list_of_maps, "\n", &Jason.encode!/1)
    File.write!(path, content <> "\n")
  end

  @doc """
  Appends a single map to a JSONL file.

  ## Parameters

    - `path` — path to the file
    - `map` — map to append
    - `opts` — reserved for future options (currently unused)

  Raises on write failure.

  ## Examples

      iex> path = Path.join(System.tmp_dir(), "apero-jsonl-#{System.unique_integer([:positive])}.jsonl")
      iex> Apero.Jsonl.write!(path, [%{a: 1}])
      :ok
      iex> Apero.Jsonl.append!(path, %{b: 2})
      :ok
  """
  @spec append!(binary(), map(), keyword()) :: :ok
  def append!(path, map, _opts \\ []) do
    File.write!(path, Jason.encode!(map) <> "\n", [:append])
  end

  @doc """
  Streams a JSONL file as an enumerable of maps.

  Lines that fail to parse are skipped. A truncated final line (no
  trailing newline, e.g. after a crash) is also skipped, with a
  `Logger.warning` when the file does not end with a newline.

  ## Parameters

    - `path` — path to the file

  ## Examples

      iex> path = Path.join(System.tmp_dir(), "apero-jsonl-#{System.unique_integer([:positive])}.jsonl")
      iex> Apero.Jsonl.write!(path, [%{a: 1}])
      :ok
      iex> Apero.Jsonl.stream!(path) |> Enum.to_list()
      [%{"a" => 1}]
  """
  @spec stream!(binary()) :: Stream.t()
  def stream!(path) do
    path
    |> File.stream!([], :line)
    |> Stream.map(&decode_line/1)
    |> Stream.reject(&is_nil/1)
  end

  @doc """
  Reads all maps from a JSONL file.

  ## Parameters

    - `path` — path to the file

  ## Examples

      iex> path = Path.join(System.tmp_dir(), "apero-jsonl-#{System.unique_integer([:positive])}.jsonl")
      iex> Apero.Jsonl.write!(path, [%{a: 1}])
      :ok
      iex> Apero.Jsonl.read_all(path)
      {:ok, [%{"a" => 1}]}
  """
  @spec read_all(binary()) :: {:ok, [map()]} | {:error, term()}
  def read_all(path) do
    case File.read(path) do
      {:ok, content} ->
        {:ok, parse_lines(content)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Recovers maps from a JSONL file, skipping corrupted lines.

  The recovery function receives each raw line and must return
  `{:ok, map}` or `{:error, _}`. Lines that return an error are skipped.

  ## Parameters

    - `path` — path to the file
    - `fun` — function that receives each line and returns `{:ok, map}`
      or `{:error, reason}`

  ## Examples

      iex> path = Path.join(System.tmp_dir(), "apero-jsonl-#{System.unique_integer([:positive])}.jsonl")
      iex> File.write!(path, "{\\"a\\": 1}\\nnot-json\\n{\\"b\\": 2}\\n")
      iex> Apero.Jsonl.recover(path, fn line -> Jason.decode(line) end)
      [%{"a" => 1}, %{"b" => 2}]
  """
  @spec recover(binary(), (binary() -> {:ok, map()} | {:error, term()})) :: [map()]
  def recover(path, fun) do
    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.flat_map(fn line ->
          case fun.(line) do
            {:ok, map} when is_map(map) -> [map]
            _ -> []
          end
        end)

      {:error, _reason} ->
        []
    end
  end

  # -- private ----------------------------------------------------------

  defp parse_lines(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Jason.decode(line) do
        {:ok, map} when is_map(map) -> [map]
        _ -> []
      end
    end)
  end

  defp decode_line(line) do
    case Jason.decode(line) do
      {:ok, map} when is_map(map) ->
        map

      {:error, _reason} ->
        warn_truncated_line(line)
        nil
    end
  end

  # Only warn about the truncation when the bad line is the last one and
  # the file does not end with a newline (crash mid-write).
  defp warn_truncated_line(line) do
    unless String.ends_with?(line, "\n") do
      Logger.warning("Apero.Jsonl: skipping truncated line: #{inspect(line)}")
    end

    :ok
  end
end
