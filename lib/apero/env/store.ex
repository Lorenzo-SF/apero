defmodule Apero.Env.Store do
  @moduledoc false

  @doc """
  Gets an environment variable, returning `default` if not set.
  """
  @spec get(binary(), any()) :: binary() | any()
  def get(key, default \\ nil) do
    System.get_env(key) || default
  end

  @doc """
  Gets an environment variable and casts it to the given type.
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

  @doc """
  Validates that all required environment variables are set.
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
end
