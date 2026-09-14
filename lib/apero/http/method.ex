defmodule Apero.Http.Method do
  @moduledoc """
  Builders for each HTTP method, mapping option keywords onto a
  `Apero.Http.Request` struct.

  Kept as a tiny helper because `Apero.Http.request/5` and friends
  pattern-match on `method_builder/1` to dispatch to the right
  per-method behaviour (e.g. setting Content-Type on POST/PUT/PATCH,
  carrying body for GET/DELETE as nil).
  """

  alias Apero.Http.Request

  @type method :: :get | :post | :put | :patch | :delete | :query

  @doc """
  Build an `Apero.Http.Request` from a method atom and option keywords.

  Recognised options:
    * `:url` (required)
    * `:headers` — list of `{name, value}` tuples (default `[]`)
    * `:body` (default `nil`)
    * `:opts` — list of adapter options (default `[]`)
  """
  @spec build(method(), keyword()) :: Request.t()
  def build(method, opts) do
    %Request{
      method: method,
      url: Keyword.fetch!(opts, :url),
      headers: Keyword.get(opts, :headers, []),
      body: Keyword.get(opts, :body, nil),
      options: Keyword.get(opts, :opts, [])
    }
  end
end
