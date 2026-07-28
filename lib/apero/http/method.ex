defmodule Apero.Http.Method do
  @moduledoc """
  Behaviour for HTTP method implementations.

  Each method module (Get, Post, Put, Patch, Delete, Query) implements
  this behaviour to build a proper `Apero.Http.Request` from raw options.

  ## Built-in methods

    * `Apero.Http.Method.Get`
    * `Apero.Http.Method.Post`
    * `Apero.Http.Method.Put`
    * `Apero.Http.Method.Patch`
    * `Apero.Http.Method.Delete`
    * `Apero.Http.Method.Query`

  ## Implementing a custom method

      defmodule MyApp.Http.Method.Head do
        @behaviour Apero.Http.Method

        @impl true
        def build(opts) do
          %Apero.Http.Request{
            method: :head,
            url: opts[:url],
            headers: opts[:headers] || [],
            body: nil,
            options: Keyword.get(opts, :opts, [])
          }
        end
      end
  """

  @doc """
  Builds a `Apero.Http.Request` from the given keyword options.

  ## Options

    * `:url` — request URL (required)
    * `:headers` — list of `{name, value}`
    * `:body` — request body (nil for methods without body)
    * `:opts` — additional options passed through to the adapter
  """
  @callback build(keyword()) :: Apero.Http.Request.t()
end
