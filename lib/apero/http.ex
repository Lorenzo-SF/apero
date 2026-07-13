defmodule Apero.Http do
  @moduledoc """
  HTTP client for Elixir — dispatcher with method-specific builders.

  ## Quick start

      # GET
      {:ok, resp} = Apero.Http.get("https://api.example.com/users")
      resp.status  # => 200
      resp.body    # => %{"data" => [...]}

      # POST with JSON body
      {:ok, resp} = Apero.Http.post("https://api.example.com/users", %{name: "Alice"})
      resp.status  # => 201

      # POST with custom headers and options
      {:ok, resp} = Apero.Http.post(
        "https://api.example.com/data",
        %{key: "value"},
        [{"authorization", "Bearer token"}],
        receive_timeout: 10_000
      )

  ## Streaming

      Apero.Http.stream(:post, url, body, headers, acc, fn entry, acc ->
        case entry do
          {:data, chunk} -> {:cont, [chunk | acc]}
          {:done, _} -> {:halt, acc}
          _ -> {:cont, acc}
        end
      end)

  ## Configuration

  The default adapter is `Apero.Http.Adapter.Finch`. Override via:

      config :apero, :http_adapter, MyApp.Http.Adapter.Custom

  Finch pool size is configurable:

      config :apero, :http_finch_pools, %{default: [size: 20, count: 2]}
  """

  @doc """
  Performs a GET request.

  ## Options

    * `:receive_timeout` — timeout in ms (default: 30_000)
    * `:pool_timeout` — pool checkout timeout in ms (default: 5_000)
  """
  @spec get(String.t(), [{String.t(), String.t()}], keyword()) ::
          {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}
  def get(url, headers \\ [], opts \\ []) do
    request(:get, url, nil, headers, opts)
  end

  @doc """
  Performs a POST request with a JSON-encodable body.

  See `get/3` for available options.
  """
  @spec post(String.t(), term(), [{String.t(), String.t()}], keyword()) ::
          {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}
  def post(url, body, headers \\ [], opts \\ []) do
    request(:post, url, body, headers, opts)
  end

  @doc """
  Performs a PUT request with a JSON-encodable body.

  See `get/3` for available options.
  """
  @spec put(String.t(), term(), [{String.t(), String.t()}], keyword()) ::
          {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}
  def put(url, body, headers \\ [], opts \\ []) do
    request(:put, url, body, headers, opts)
  end

  @doc """
  Performs a PATCH request with a JSON-encodable body.

  See `get/3` for available options.
  """
  @spec patch(String.t(), term(), [{String.t(), String.t()}], keyword()) ::
          {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}
  def patch(url, body, headers \\ [], opts \\ []) do
    request(:patch, url, body, headers, opts)
  end

  @doc """
  Performs a DELETE request.
  """
  @spec delete(String.t(), [{String.t(), String.t()}], keyword()) ::
          {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}
  def delete(url, headers \\ [], opts \\ []) do
    request(:delete, url, nil, headers, opts)
  end

  @doc """
  Performs a QUERY request (RFC 7231) — idempotent with body semantics.
  """
  @spec query(String.t(), term(), [{String.t(), String.t()}], keyword()) ::
          {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}
  def query(url, body, headers \\ [], opts \\ []) do
    request(:query, url, body, headers, opts)
  end

  @doc """
  Performs a raw request by method atom.

  Useful for dynamic method dispatch:

      Apero.Http.request(:get, url, nil, headers, opts)
  """
  @spec request(atom(), String.t(), term(), [{String.t(), String.t()}], keyword()) ::
          {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}
  def request(method, url, body, headers \\ [], opts \\ []) do
    builder = method_builder(method)
    req = builder.build(url: url, headers: headers, body: body, opts: opts)

    adapter().request(req)
  end

  @doc """
  Streams an HTTP response via callback.

  `acc` is the initial accumulator. `fun` receives `(entry, acc)` where
  `entry` is one of `{:status, s}`, `{:headers, h}`, `{:data, bin}`,
  `{:trailers, t}`, or `{:done, :done}`. Must return `{:cont, acc}` or
  `{:halt, acc}`.

  Returns `{:ok, final_acc}` or `{:error, Apero.Http.Error.t()}`.
  """
  @spec stream(
          atom(),
          String.t(),
          term(),
          [{String.t(), String.t()}],
          term(),
          function(),
          keyword()
        ) ::
          {:ok, term()} | {:error, Apero.Http.Error.t()}
  def stream(method, url, body, headers, acc, fun, opts \\ []) do
    builder = method_builder(method)
    req = builder.build(url: url, headers: headers, body: body, opts: opts)

    adapter().stream(req, acc, fun, opts)
  end

  # ── Internals ────────────────────────────────────────────────────────────

  defp adapter do
    Application.get_env(:apero, :http_adapter, Apero.Http.Adapter.Finch)
  end

  defp method_builder(:get), do: Apero.Http.Method.Get
  defp method_builder(:post), do: Apero.Http.Method.Post
  defp method_builder(:put), do: Apero.Http.Method.Put
  defp method_builder(:patch), do: Apero.Http.Method.Patch
  defp method_builder(:delete), do: Apero.Http.Method.Delete
  defp method_builder(:query), do: Apero.Http.Method.Query
end
