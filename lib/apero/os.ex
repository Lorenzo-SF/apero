defmodule Apero.OS do
  @moduledoc """
  Operating system information utilities for Apero (pure-Elixir subset).

  Provides a minimal interface for querying OS type and hostname using
  only pure Erlang/Elixir standard library calls — no shell execution.

  For shell-based operations (arch, kernel version, distribution, CPU
  count, memory, root check, WSL/container detection) see `Trebejo.OS`.
  """

  @type os_type :: :linux | :macos | :windows | :unknown

  @doc """
  Returns the operating system type.

  Possible values: `:linux`, `:macos`, `:windows`, `:unknown`.
  """
  @spec type() :: os_type()
  def type do
    case :os.type() do
      {:unix, :linux} -> :linux
      {:unix, :darwin} -> :macos
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end

  @doc """
  Returns the machine hostname.
  """
  @dialyzer {:nowarn_function, hostname: 0}
  @spec hostname() :: binary()
  def hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "localhost"
    end
  end
end
