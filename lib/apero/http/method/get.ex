defmodule Apero.Http.Method.Get do
  @moduledoc """
  Builds a GET request. GET requests have no body.
  """

  @behaviour Apero.Http.Method

  @impl true
  def build(opts) do
    %Apero.Http.Request{
      method: :get,
      url: Keyword.fetch!(opts, :url),
      headers: Keyword.get(opts, :headers, []),
      body: nil,
      options: Keyword.get(opts, :opts, [])
    }
  end
end
