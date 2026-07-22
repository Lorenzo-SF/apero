defmodule Apero.Conf.Atom do
  @moduledoc false

  @doc """
  Safely converts a string to an existing atom.
  Returns `{:ok, atom}` if the atom exists, `:error` otherwise.
  """
  @spec safe_to_atom(String.t()) :: {:ok, atom()} | :error
  def safe_to_atom(key) when is_binary(key) do
    {:ok, String.to_existing_atom(key)}
  rescue
    ArgumentError -> :error
  end

  @doc """
  Returns an existing atom for a string key, or the string if no atom exists.
  """
  @spec safe_key(String.t()) :: atom() | String.t()
  def safe_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  @doc """
  Finds a key in a map, matching by string or existing atom.
  Returns the matched key or `nil`.
  """
  @spec existing_key(map(), String.t()) :: term() | nil
  def existing_key(map, key) do
    if Map.has_key?(map, key) do
      key
    else
      find_atom_key(map, key)
    end
  end

  @doc false
  @spec find_atom_key(map(), String.t()) :: atom() | nil
  def find_atom_key(map, key) do
    Enum.find_value(map, fn
      {candidate, _value} when is_atom(candidate) ->
        if Atom.to_string(candidate) == key, do: candidate

      _other ->
        nil
    end)
  end
end
