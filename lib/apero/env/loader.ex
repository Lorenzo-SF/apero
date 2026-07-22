defmodule Apero.Env.Loader do
  @moduledoc false

  @doc """
  Loads a `.env` file and puts each key-value pair into the process environment.
  """
  @spec load(binary()) :: {:ok, map()} | {:error, binary()}
  def load(path) do
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
  def read(path) do
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
