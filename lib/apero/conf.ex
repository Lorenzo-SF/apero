defmodule Apero.Conf do
  @compile {:no_warn_undefined, {YamlElixir, :read_from_string!, 1}}
  @compile {:no_warn_undefined, {Toml, :decode, 1}}

  @moduledoc """
  Configuration file management — unified interface for JSON, YAML and TOML.

  Provides operations for loading, validating, writing and merging config files
  regardless of their format. The format is auto-detected from the file extension
  and can be explicitly specified.

  For `.env` files and environment variables, use `Apero.Env`.
  """

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

  @doc """
  Gets a nested value from a config map using dot-separated key path.

  ## Examples

      iex> Conf.get(%{retrieval: %{vector_weight: 0.5}}, "retrieval.vector_weight")
      0.5

      iex> Conf.get(%{foo: 1}, "bar")
      nil
  """
  @spec get(map(), String.t()) :: term()
  def get(config, key_path) when is_binary(key_path) do
    keys = String.split(key_path, ".")
    deep_get(config, keys, &String.to_atom/1)
  end

  defp deep_get(map, [key], _to_atom) when is_map(map) do
    case map do
      %{^key => value} -> value
      %{} -> Map.get(map, key_to_atom(key), nil)
    end
  end

  defp deep_get(map, [key | rest], to_atom) when is_map(map) do
    case map do
      %{^key => sub} -> deep_get(sub, rest, to_atom)
      %{} -> deep_get(Map.get(map, key_to_atom(key), %{}), rest, to_atom)
    end
  end

  defp deep_get(_, _, _), do: nil

  defp key_to_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> atomize(key)
  end

  defp atomize(key) do
    unless String.match?(key, ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/) do
      raise ArgumentError,
            "cannot convert \"#{key}\" to atom: invalid characters (only letters, numbers, and underscores allowed)"
    end

    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom(key)
  end

  @doc """
  Sets a nested value in a config map using dot-separated key path.

  Returns an updated config map (immutable — original is not modified).

  ## Examples

      iex> Conf.set(%{retrieval: %{vector_weight: 0.5}}, "retrieval.vector_weight", 0.8)
      %{retrieval: %{vector_weight: 0.8}}
  """
  @spec set(map(), String.t(), term()) :: map()
  def set(config, key_path, value) when is_binary(key_path) do
    keys = String.split(key_path, ".")
    atoms = Enum.map(keys, &key_to_atom/1)
    put_in(config, atoms, value)
  end

  @doc "Validates a config map against a schema map (shallow key-type check)."
  @spec validate(map(), map()) :: :ok | {:error, [String.t()]}
  def validate(config, schema) when is_map(config) and is_map(schema) do
    errors =
      Enum.flat_map(schema, fn {key, expected_type} ->
        value = Map.get(config, key)

        cond do
          is_nil(value) and not Map.has_key?(config, key) ->
            ["Missing required key: #{key}"]

          not type_matches?(value, expected_type) ->
            ["#{key}: expected #{expected_type}, got #{type_of(value)}"]

          true ->
            []
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @doc "Merges a list of config maps. Later entries override earlier ones."
  @spec merge([map()]) :: map()
  def merge(configs) when is_list(configs), do: Enum.reduce(configs, %{}, &Map.merge(&2, &1))

  @doc "Prints a formatted summary of a config map to the terminal."
  @spec print_summary(map(), String.t()) :: :ok
  def print_summary(config, title \\ "Configuration") do
    IO.puts("#{title}:")

    config
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.each(fn {k, v} ->
      IO.puts("   #{String.pad_trailing(to_string(k), 24)} #{inspect(v)}")
    end)

    :ok
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

  # ── Private ────────────────────────────────────────────────────────

  defp type_matches?(value, :string), do: is_binary(value)
  defp type_matches?(value, :integer), do: is_integer(value)
  defp type_matches?(value, :float), do: is_float(value) or is_integer(value)
  defp type_matches?(value, :boolean), do: is_boolean(value)
  defp type_matches?(value, :list), do: is_list(value)
  defp type_matches?(value, :map), do: is_map(value)
  defp type_matches?(_value, :any), do: true
  defp type_matches?(_value, _), do: true

  defp type_of(value) when is_binary(value), do: "string"
  defp type_of(value) when is_integer(value), do: "integer"
  defp type_of(value) when is_float(value), do: "float"
  defp type_of(value) when is_boolean(value), do: "boolean"
  defp type_of(value) when is_list(value), do: "list"
  defp type_of(value) when is_map(value), do: "map"
  defp type_of(_), do: "unknown"

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
