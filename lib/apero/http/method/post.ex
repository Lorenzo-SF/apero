defmodule Apero.Http.Method.Post do
  @moduledoc """
  Builder for the :post HTTP method.

  Delegates to .
  """

  alias Apero.Http.Method
  alias Apero.Http.Request

  @spec build(keyword()) :: Request.t()
  def build(opts), do: Method.build(:post, opts)
end
