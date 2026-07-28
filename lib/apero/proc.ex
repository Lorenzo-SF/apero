defmodule Apero.Proc do
  @moduledoc """
  Process and executable utilities for Apero (pure-Elixir subset).

  Provides helpers for checking command availability, finding executables,
  and VM introspection. All functions are pure Elixir/Erlang — no shell
  execution involved.

  For shell-based operations (process listing, signalling, logs, lsof,
  fuser) see `Trebejo.Proc`.
  """

  @doc "Returns `true` if the given command exists in the system `PATH`."
  @spec command_exists?(String.t()) :: boolean()
  def command_exists?(cmd) when is_binary(cmd) and byte_size(cmd) > 0,
    do: System.find_executable(cmd) != nil

  def command_exists?(_), do: false

  @doc "Returns the full path of a command if found, or `nil`."
  @spec which(String.t()) :: String.t() | nil
  def which(cmd), do: System.find_executable(cmd)

  @doc "Filters a list of commands to only those available on the system."
  @spec available_commands([String.t()]) :: [String.t()]
  def available_commands(commands) when is_list(commands),
    do: Enum.filter(commands, &command_exists?/1)

  @doc "Returns a map of `command => path` for all found commands."
  @spec locate_commands([String.t()]) :: %{String.t() => String.t()}
  def locate_commands(commands) when is_list(commands) do
    commands
    |> Enum.map(&{&1, which(&1)})
    |> Enum.filter(fn {_, path} -> path != nil end)
    |> Map.new()
  end

  @doc "Returns the OS process ID of the BEAM VM."
  @spec os_pid() :: non_neg_integer()
  def os_pid, do: :os.getpid() |> List.to_integer()

  @doc "Returns the number of scheduler threads."
  @spec scheduler_count() :: non_neg_integer()
  def scheduler_count, do: :erlang.system_info(:schedulers)

  @doc "Returns the VM memory usage in bytes."
  @spec vm_memory() :: non_neg_integer()
  def vm_memory, do: :erlang.memory(:total)

  @doc "Returns the VM uptime in milliseconds."
  @spec vm_uptime() :: non_neg_integer()
  def vm_uptime do
    :erlang.statistics(:wall_clock)
    |> elem(1)
  end
end
