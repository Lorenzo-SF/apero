defmodule Apero.Http.Method.Delete do
  @moduledoc """
  Builds a DELETE request. DELETE requests may optionally carry a body.
  """

  @behaviour Apero.Http.Method

  @impl true
  def build(opts) do
    body = Keyword.get(opts, :body)

    %Apero.Http.Request{
      method: :delete,
      url: Keyword.fetch!(opts, :url),
      headers: Keyword.get(opts, :headers, []),
      body: body,
      options: Keyword.get(opts, :opts, [])
    }
  end
end
