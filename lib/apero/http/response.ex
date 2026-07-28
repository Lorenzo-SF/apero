defmodule Apero.Http.Response do
  @moduledoc """
  Represents an HTTP response.

  Returned by `Apero.Http.Adapter` implementations.
  """

  defstruct [:status, :headers, :body]

  @type t :: %__MODULE__{
          status: pos_integer(),
          headers: [{String.t(), String.t()}],
          body: term()
        }
end
