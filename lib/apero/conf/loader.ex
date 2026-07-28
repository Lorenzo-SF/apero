defmodule Apero.Conf.Loader do
  @compile {:no_warn_undefined, {YamlElixir, :read_from_string!, 1}}
  @compile {:no_warn_undefined, {Toml, :decode, 1}}

  @moduledoc false

  @type format :: :json | :yaml | :toml

  @doc "Loads a config file. Format is auto-detected from extension."
  @spec load(Path.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def load(path, opts \\ []) do
    format = Keyword.get(opts, :format) || detect_format(path)

    case File.read(path) do
      {:ok, content} -> parse(content, format)
      error -> error
    end
  end

  @doc "Parses a config string in the given format."
  @spec parse(String.t(), format()) :: {:ok, map()} | {:error, term()}
  def parse(content, :json), do: Jason.decode(content)

  def parse(content, :yaml) do
    if Code.ensure_loaded?(YamlElixir) do
      try do
        {:ok, YamlElixir.read_from_string!(content)}
      rescue
        e -> {:error, Exception.message(e)}
      end
    else
      {:error, "yaml_elixir dependency not available"}
    end
  end

  def parse(content, :toml) do
    if Code.ensure_loaded?(Toml) do
      case Toml.decode(content) do
        {:ok, _} = ok -> ok
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "toml dependency not available"}
    end
  end

  @doc "Writes a map to a config file."
  @spec write(Path.t(), map(), keyword()) :: :ok | {:error, term()}
  def write(path, data, opts \\ []) when is_map(data) do
    format = Keyword.get(opts, :format) || detect_format(path)

    with {:ok, encoded} <- encode(data, format) do
      File.write(path, encoded)
    end
  end

  @doc "Serializes a map to a config string."
  @spec encode(map(), format()) :: {:ok, String.t()} | {:error, term()}
  def encode(data, :json), do: {:ok, Jason.encode!(data, pretty: true)}

  def encode(_data, :yaml) do
    if Code.ensure_loaded?(YamlElixir) do
      {:error, "yaml_elixir library does not support encoding (read-only)"}
    else
      {:error, "yaml_elixir dependency not available"}
    end
  end

  def encode(data, :toml) do
    {:ok, encode_toml(data)}
  end

  @doc "Detects the config format from a file extension."
  @spec detect_format(Path.t()) :: format()
  def detect_format(path) do
    ext = path |> String.downcase() |> Path.extname()

    case ext do
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      ".toml" -> :toml
      _ -> :json
    end
  end

  # ── TOML encoder ──────────────────────────────────────────────────────

  defp encode_toml(data), do: encode_toml(data, [])

  defp encode_toml(data, path) when is_map(data) do
    {scalars, sections} = Enum.split_with(data, fn {_k, v} -> not is_map(v) end)
    {simple_scalars, arrays} = Enum.split_with(scalars, fn {_k, v} -> not is_list(v) end)

    scalar_lines =
      Enum.map(simple_scalars, fn {k, v} ->
        "#{toml_key(k)} = #{toml_value(v)}\n"
      end)

    array_lines =
      Enum.map(arrays, fn {k, v} ->
        "#{toml_key(k)} = [#{Enum.map_join(v, ", ", &toml_value/1)}]\n"
      end)

    section_lines =
      Enum.flat_map(sections, fn {k, v} ->
        section_path = path ++ [k]
        section_header = "\n[#{Enum.map_join(section_path, ".", &toml_key/1)}]\n"
        encoded = encode_toml(v, section_path)
        lines = String.split(encoded, "\n", trim: true)
        [section_header | Enum.map(lines, &(&1 <> "\n"))]
      end)

    (scalar_lines ++ array_lines ++ section_lines) |> Enum.join("")
  end

  defp toml_key(key) when is_atom(key), do: toml_key(Atom.to_string(key))
  defp toml_key(key) when is_binary(key), do: key

  defp toml_value(value) when is_binary(value), do: ~s("#{escape_toml_string(value)}")
  defp toml_value(value) when is_integer(value), do: Integer.to_string(value)
  defp toml_value(value) when is_float(value), do: Float.to_string(value)
  defp toml_value(value) when is_boolean(value), do: if(value, do: "true", else: "false")

  defp escape_toml_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end
end
