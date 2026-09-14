defmodule Apero.Http.Method.Delete do
  @moduledoc """
  Builder for the :delete HTTP method.

  Delegates to .
  """

  alias Apero.Http.Method
  alias Apero.Http.Request

  @spec build(keyword()) :: Request.t()
  def build(opts), do: Method.build(:delete, opts)
end
