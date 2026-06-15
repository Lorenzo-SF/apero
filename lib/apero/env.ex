defmodule Apero.Env do
  @moduledoc """
  Environment variable management for Apero.

  Provides loading from `.env` files, merging with system environment,
  value parsing, required-variable validation and type coercion.

  ## Loading a `.env` file

      Apero.Env.load(".env")
      System.get_env("MY_VAR")  # now available

  """

  @doc """
  Loads a `.env` file and puts each key-value pair into the process environment.

  Lines starting with `#` and empty lines are ignored. Both `KEY=VALUE` and
  `export KEY=VALUE` formats are supported. Values may optionally be quoted.

  Returns the loaded values as a map.
  """
  @spec load(binary()) :: {:ok, map()} | {:error, binary()}
  def load(path \\ ".env") do
    case File.read(path) do
      {:ok, content} ->
        vars =
          content
          |> String.split("\n", trim: true)
          |> Enum.reject(&comment_or_blank?/1)
          |> Enum.reduce(%{}, &load_line/2)

        {:ok, vars}

      {:error, reason} ->
        {:error, "Cannot read #{path}: #{reason}"}
    end
  end

  @doc """
  Reads a `.env` file and returns its contents as a map without modifying
  the process environment.
  """
  @spec read(binary()) :: {:ok, map()} | {:error, binary()}
  def read(path \\ ".env") do
    case File.read(path) do
      {:ok, content} ->
        vars =
          content
          |> String.split("\n", trim: true)
          |> Enum.reject(&comment_or_blank?/1)
          |> Enum.reduce(%{}, &read_line/2)

        {:ok, vars}

      {:error, reason} ->
        {:error, "Cannot read #{path}: #{reason}"}
    end
  end

  @doc """
  Writes a map of key-value pairs to a `.env` file.

  Existing content is replaced. Values containing spaces are quoted.
  """
  @spec write(binary(), map()) :: :ok | {:error, binary()}
  def write(path \\ ".env", vars) when is_map(vars) do
    content =
      vars
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map_join("\n", fn {k, v} ->
        value = if needs_quoting?(to_string(v)), do: "\"#{v}\"", else: to_string(v)
        "#{k}=#{value}"
      end)

    case File.write(path, content <> "\n") do
      :ok -> :ok
      {:error, reason} -> {:error, "Cannot write #{path}: #{reason}"}
    end
  end

  @doc """
  Gets an environment variable, returning `default` if not set.
  """
  @spec get(binary(), any()) :: binary() | any()
  def get(key, default \\ nil) do
    System.get_env(key) || default
  end

  @doc """
  Gets an environment variable and casts it to the given type.

  Supported types: `:string`, `:integer`, `:float`, `:boolean`, `:atom`.

  Returns `{:ok, value}` or `{:error, reason}`.

  ## Examples

      iex> System.put_env("PORT", "4000")
      iex> Apero.Env.get_as("PORT", :integer)
      {:ok, 4000}

      iex> System.put_env("DEBUG", "true")
      iex> Apero.Env.get_as("DEBUG", :boolean)
      {:ok, true}

  """
  @spec get_as(binary(), :string | :integer | :float | :boolean | :atom) ::
          {:ok, any()} | {:error, binary()}
  def get_as(key, type) do
    case System.get_env(key) do
      nil -> {:error, "#{key} is not set"}
      value -> cast(value, type)
    end
  end

  @doc """
  Validates that all required environment variables are set.

  Returns `{:ok, map}` with the values, or `{:error, [missing_keys]}`.

  ## Examples

      iex> System.put_env("HOST", "localhost")
      iex> {:ok, values} = Apero.Env.require_keys(["HOST"])
      iex> values["HOST"]
      "localhost"

  """
  @spec require_keys([binary()]) :: {:ok, map()} | {:error, [binary()]}
  def require_keys(keys) when is_list(keys) do
    {found, missing} =
      Enum.reduce(keys, {%{}, []}, fn key, {found_acc, missing_acc} ->
        case System.get_env(key) do
          nil -> {found_acc, [key | missing_acc]}
          val -> {Map.put(found_acc, key, val), missing_acc}
        end
      end)

    if missing == [] do
      {:ok, found}
    else
      {:error, Enum.reverse(missing)}
    end
  end

  @doc """
  Sets a key-value pair in the process environment.
  """
  @spec put(binary(), binary()) :: :ok
  def put(key, value) when is_binary(key) and is_binary(value) do
    System.put_env(key, value)
  end

  @doc """
  Removes a key from the process environment.
  """
  @spec delete(binary()) :: :ok
  def delete(key) when is_binary(key) do
    System.delete_env(key)
  end

  @doc """
  Returns a map of all current environment variables.
  """
  @spec all() :: map()
  def all do
    System.get_env()
  end

  defp parse_line(line) do
    line = String.trim(line)
    line = if String.starts_with?(line, "export "), do: String.slice(line, 7..-1//1), else: line

    case String.split(line, "=", parts: 2) do
      [key, value] ->
        key = String.trim(key)
        value = value |> String.trim() |> strip_quotes()

        if valid_key?(key), do: {key, value}, else: nil

      _ ->
        nil
    end
  end

  defp strip_quotes(str) do
    cond do
      String.starts_with?(str, "\"") and String.ends_with?(str, "\"") ->
        str |> String.slice(1..-2//1)

      String.starts_with?(str, "'") and String.ends_with?(str, "'") ->
        str |> String.slice(1..-2//1)

      true ->
        str
    end
  end

  defp comment_or_blank?(line) do
    trimmed = String.trim(line)
    trimmed == "" or String.starts_with?(trimmed, "#")
  end

  defp valid_key?(key), do: Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_]*$/, key)

  defp needs_quoting?(value), do: String.contains?(value, [" ", "\t", "#"])

  defp cast(value, :string), do: {:ok, value}

  defp cast(value, :atom) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> {:error, "Unknown or unsafe atom: #{value}"}
  end

  defp cast(value, :integer) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Cannot parse '#{value}' as integer"}
    end
  end

  defp cast(value, :float) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "Cannot parse '#{value}' as float"}
    end
  end

  defp cast(value, :boolean) do
    case String.downcase(String.trim(value)) do
      v when v in ["true", "1", "yes", "on"] -> {:ok, true}
      v when v in ["false", "0", "no", "off"] -> {:ok, false}
      _ -> {:error, "Cannot parse '#{value}' as boolean"}
    end
  end

  defp cast(_value, type), do: {:error, "Unsupported type: #{type}"}

  defp load_line(line, acc) do
    case parse_line(line) do
      {key, value} ->
        System.put_env(key, value)
        Map.put(acc, key, value)

      nil ->
        acc
    end
  end

  defp read_line(line, acc) do
    case parse_line(line) do
      {key, value} -> Map.put(acc, key, value)
      nil -> acc
    end
  end
end
