defmodule Apero.Http.Method.Put do
  @moduledoc """
  Builds a PUT request. PUT requests carry a body.
  """

  @behaviour Apero.Http.Method

  @impl true
  def build(opts) do
    body = Keyword.get(opts, :body)

    %Apero.Http.Request{
      method: :put,
      url: Keyword.fetch!(opts, :url),
      headers: Keyword.get(opts, :headers, []),
      body: body,
      options: Keyword.get(opts, :opts, [])
    }
  end
end
