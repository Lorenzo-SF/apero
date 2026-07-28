defmodule Apero.Env.Serializer do
  @moduledoc false

  @doc """
  Writes a map of key-value pairs to a `.env` file.
  """
  @spec write(binary(), map()) :: :ok | {:error, binary()}
  def write(path, vars) when is_map(vars) do
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

  defp needs_quoting?(value), do: String.contains?(value, [" ", "\t", "#"])
end
