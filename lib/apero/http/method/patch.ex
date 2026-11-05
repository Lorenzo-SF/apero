defmodule Apero.Http.Method.Patch do
  @moduledoc """
  Builder for the :patch HTTP method.

  Delegates to .
  """

  alias Apero.Http.Method
  alias Apero.Http.Request

  @spec build(keyword()) :: Request.t()
  def build(opts), do: Method.build(:patch, opts)
end
