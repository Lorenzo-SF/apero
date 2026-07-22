defmodule Apero.Conf do
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
  defdelegate load(path, opts \\ []), to: Apero.Conf.Loader

  @doc "Parses a config string in the given format."
  @spec parse(String.t(), format()) :: {:ok, map()} | {:error, term()}
  defdelegate parse(content, format), to: Apero.Conf.Loader

  @doc "Writes a map to a config file."
  @spec write(Path.t(), map(), keyword()) :: :ok | {:error, term()}
  defdelegate write(path, data, opts \\ []), to: Apero.Conf.Loader

  @doc "Serializes a map to a config string."
  @spec encode(map(), format()) :: {:ok, String.t()} | {:error, term()}
  defdelegate encode(data, format), to: Apero.Conf.Loader

  @doc "Validates a config map against a schema map (shallow key-type check)."
  @spec validate(map(), map()) :: :ok | {:error, [String.t()]}
  defdelegate validate(config, schema), to: Apero.Conf.Validator

  @doc "Detects the config format from a file extension."
  @spec detect_format(Path.t()) :: format()
  defdelegate detect_format(path), to: Apero.Conf.Loader

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
    deep_get(config, String.split(key_path, "."))
  end

  defp deep_get(map, [key]) when is_map(map) do
    case Apero.Conf.Atom.existing_key(map, key) do
      nil -> nil
      actual_key -> Map.fetch!(map, actual_key)
    end
  end

  defp deep_get(map, [key | rest]) when is_map(map) do
    case Apero.Conf.Atom.existing_key(map, key) do
      nil -> nil
      actual_key -> deep_get(Map.fetch!(map, actual_key), rest)
    end
  end

  defp deep_get(_, _), do: nil

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
    deep_set(config, keys, value)
  end

  defp deep_set(map, [key], value) when is_map(map) do
    Map.put(map, Apero.Conf.Atom.safe_key(key), value)
  end

  defp deep_set(map, [key | rest], value) when is_map(map) do
    lookup = Apero.Conf.Atom.safe_key(key)

    sub =
      case Map.fetch(map, lookup) do
        {:ok, existing} when is_map(existing) -> existing
        _ -> %{}
      end

    Map.put(map, lookup, deep_set(sub, rest, value))
  end

  defp deep_set(_, _, _), do: %{}

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
end
