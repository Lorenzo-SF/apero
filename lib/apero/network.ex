defmodule Apero.Network do
  @moduledoc """
  Network operations: ping, DNS, TCP port checks.
  """

  @type tcp_port :: 0..65_535

  @doc """
  Sends ICMP ping to a host.

  Returns `:ok` on success or `{:error, reason}` on failure.

  ## Options

    * `:count` — number of echo requests (default: 3)
    * `:timeout` — timeout in ms (default: 5_000)
  """
  @spec ping(String.t(), keyword()) :: :ok | {:error, term()}
  def ping(host, opts \\ []) do
    count = Keyword.get(opts, :count, 3)
    timeout = Keyword.get(opts, :timeout, 5_000)

    args = ["-c", to_string(count), "-W", to_string(div(timeout, 1000)), host]

    case System.cmd("ping", args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:ping_failed, code, output}}
    end
  end

  @doc """
  Resolves a hostname to a list of IP addresses.

  Returns `{:ok, [String.t()]}` or `{:error, :nxdomain}` on failure.
  """
  @spec resolve(String.t()) :: {:ok, [String.t()]} | {:error, atom()}
  def resolve(host) do
    case :inet.gethostbyname(String.to_charlist(host)) do
      {:ok, {:hostent, _, _, _, _, addresses}} ->
        {:ok, Enum.map(addresses, fn addr -> addr |> :inet.ntoa() |> List.to_string() end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a TCP port is open on a host.

  ## Options

    * `:timeout` — connection timeout in ms (default: 5_000)
  """
  @spec port_open?(String.t(), tcp_port(), keyword()) :: boolean()
  def port_open?(host, port, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)

    case :gen_tcp.connect(
           String.to_charlist(host),
           port,
           [:binary, active: false, packet: 0],
           timeout
         ) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end

  @doc """
  Scans a list of TCP ports on a host.

  Returns a map of port → `:open | :closed`.
  """
  @spec scan_ports(String.t(), [tcp_port()], keyword()) :: %{tcp_port() => :open | :closed}
  def scan_ports(host, ports, opts \\ []) do
    Enum.into(ports, %{}, fn port ->
      {port, if(port_open?(host, port, opts), do: :open, else: :closed)}
    end)
  end
end
