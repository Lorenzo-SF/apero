defmodule Apero.Http.Adapter do
  @moduledoc """
  Behaviour for HTTP transport adapters.

  Each adapter implements the actual HTTP call (Finch, Mint, httpc,
  mock, etc.) and translates to/from `Apero.Http.Request` /
  `Apero.Http.Response`.

  ## Built-in adapters

    * `Apero.Http.Adapter.Finch` — default, uses Finch for transport

  ## Implementing a custom adapter

      defmodule MyApp.Http.Adapter.Mock do
        @behaviour Apero.Http.Adapter

        @impl true
        def request(request) do
          # return {:ok, %Apero.Http.Response{...}} or {:error, %Apero.Http.Error{...}}
        end

        @impl true
        def stream(request, acc, fun, opts) do
          # stream response chunks via fun callback
        end
      end
  """

  @doc """
  Performs a single HTTP request and returns the response.

  Returns `{:ok, Apero.Http.Response.t()}` on success, or
  `{:error, Apero.Http.Error.t()}` on failure.
  """
  @callback request(Apero.Http.Request.t()) ::
              {:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}

  @doc """
  Streams the response body via a callback.

  `fun` receives `(entry, acc)` and must return `{:cont, acc}` or
  `{:halt, acc}`. Entries are:

    * `{:status, status}`
    * `{:headers, headers}`
    * `{:data, binary}`
    * `{:trailers, trailers}`
    * `{:done, :done}`

  Returns `{:ok, final_acc}` or `{:error, Apero.Http.Error.t()}`.
  """
  @callback stream(Apero.Http.Request.t(), term(), function(), keyword()) ::
              {:ok, term()} | {:error, Apero.Http.Error.t()}
end
