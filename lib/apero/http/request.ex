defmodule Apero.Http.Request do
  @moduledoc """
  Represents an HTTP request.

  Built by `Apero.Http.Method` implementations and consumed by
  `Apero.Http.Adapter` implementations.
  """

  defstruct [:method, :url, :headers, :body, :options]

  @type method :: :get | :post | :put | :patch | :delete | :query

  @type t :: %__MODULE__{
          method: method(),
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: term(),
          options: keyword()
        }
end
