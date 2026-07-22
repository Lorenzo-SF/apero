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

  **⚠️ Side-effect:** This function mutates the global OS environment for
  the entire BEAM virtual machine via `System.put_env/2`. Use with caution
  in multi-application deployments.

  Returns the loaded values as a map.
  """
  @spec load(binary()) :: {:ok, map()} | {:error, binary()}
  def load(path \\ ".env") do
    Apero.Env.Loader.load(path)
  end

  @doc """
  Reads a `.env` file and returns its contents as a map without modifying
  the process environment.
  """
  @spec read(binary()) :: {:ok, map()} | {:error, binary()}
  def read(path \\ ".env") do
    Apero.Env.Loader.read(path)
  end

  @doc """
  Writes a map of key-value pairs to a `.env` file.

  Existing content is replaced. Values containing spaces are quoted.
  """
  @spec write(binary(), map()) :: :ok | {:error, binary()}
  def write(path \\ ".env", vars) when is_map(vars) do
    Apero.Env.Serializer.write(path, vars)
  end

  @doc """
  Gets an environment variable, returning `default` if not set.
  """
  @spec get(binary(), any()) :: binary() | any()
  def get(key, default \\ nil) do
    Apero.Env.Store.get(key, default)
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
    Apero.Env.Store.get_as(key, type)
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
    Apero.Env.Store.require_keys(keys)
  end

  @doc """
  Sets a key-value pair in the process environment.
  """
  @spec put(binary(), binary()) :: :ok
  def put(key, value) when is_binary(key) and is_binary(value) do
    Apero.Env.Store.put(key, value)
  end

  @doc """
  Removes a key from the process environment.
  """
  @spec delete(binary()) :: :ok
  def delete(key) when is_binary(key) do
    Apero.Env.Store.delete(key)
  end

  @doc """
  Returns a map of all current environment variables.
  """
  @spec all() :: map()
  def all do
    Apero.Env.Store.all()
  end
end
