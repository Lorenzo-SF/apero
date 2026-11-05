defmodule Apero.Http.Method.Put do
  @moduledoc """
  Builder for the :put HTTP method.

  Delegates to .
  """

  alias Apero.Http.Method
  alias Apero.Http.Request

  @spec build(keyword()) :: Request.t()
  def build(opts), do: Method.build(:put, opts)
end
