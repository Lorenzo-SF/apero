defmodule Apero.Conf.Validator do
  @moduledoc false

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

  # ── Private ────────────────────────────────────────────────────────

  defp type_matches?(value, :string), do: is_binary(value)
  defp type_matches?(value, :integer), do: is_integer(value)
  defp type_matches?(value, :float), do: is_float(value) or is_integer(value)
  defp type_matches?(value, :boolean), do: is_boolean(value)
  defp type_matches?(value, :list), do: is_list(value)
  defp type_matches?(value, :map), do: is_map(value)
  defp type_matches?(_value, :any), do: true

  defp type_matches?(_value, unknown_type) do
    require Logger
    Logger.warning("unknown schema type: #{inspect(unknown_type)}")
    false
  end

  defp type_of(value) when is_binary(value), do: "string"
  defp type_of(value) when is_integer(value), do: "integer"
  defp type_of(value) when is_float(value), do: "float"
  defp type_of(value) when is_boolean(value), do: "boolean"
  defp type_of(value) when is_list(value), do: "list"
  defp type_of(value) when is_map(value), do: "map"
  defp type_of(_), do: "unknown"
end
