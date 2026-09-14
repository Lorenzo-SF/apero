defmodule Apero.Http.Method.Get do
  @moduledoc """
  Builder for the :get HTTP method.

  Delegates to .
  """

  alias Apero.Http.Method
  alias Apero.Http.Request

  @spec build(keyword()) :: Request.t()
  def build(opts), do: Method.build(:get, opts)
end
