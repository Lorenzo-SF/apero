defmodule Apero.Http.Method.Patch do
  @moduledoc """
  Builds a PATCH request. PATCH requests carry a body.
  """

  @behaviour Apero.Http.Method

  @impl true
  def build(opts) do
    body = Keyword.get(opts, :body)

    %Apero.Http.Request{
      method: :patch,
      url: Keyword.fetch!(opts, :url),
      headers: Keyword.get(opts, :headers, []),
      body: body,
      options: Keyword.get(opts, :opts, [])
    }
  end
end
