defmodule Apero.Http.Method.Query do
  @moduledoc """
  Builds a QUERY request (HTTP QUERY, RFC 7231).

  QUERY is an idempotent method like GET but carries a body (similar
  to POST for request semantics but with GET-like caching and
  idempotency guarantees).
  """

  @behaviour Apero.Http.Method

  @impl true
  def build(opts) do
    body = Keyword.get(opts, :body)

    %Apero.Http.Request{
      method: :query,
      url: Keyword.fetch!(opts, :url),
      headers: Keyword.get(opts, :headers, []),
      body: body,
      options: Keyword.get(opts, :opts, [])
    }
  end
end
