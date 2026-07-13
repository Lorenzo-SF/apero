defmodule Apero.Http.Method.Post do
  @moduledoc """
  Builds a POST request. POST requests carry a body.
  """

  @behaviour Apero.Http.Method

  @impl true
  def build(opts) do
    body = Keyword.get(opts, :body)

    %Apero.Http.Request{
      method: :post,
      url: Keyword.fetch!(opts, :url),
      headers: Keyword.get(opts, :headers, []),
      body: body,
      options: Keyword.get(opts, :opts, [])
    }
  end
end
