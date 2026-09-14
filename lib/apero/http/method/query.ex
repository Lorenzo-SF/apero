defmodule Apero.Http.Method.Query do
  @moduledoc """
  Builder for the :query HTTP method.

  Delegates to .
  """

  alias Apero.Http.Method
  alias Apero.Http.Request

  @spec build(keyword()) :: Request.t()
  def build(opts), do: Method.build(:query, opts)
end
