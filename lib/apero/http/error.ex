defmodule Apero.Http.Error do
  @moduledoc """
  Represents an HTTP-level or transport-level error.

  Wraps Finch/Mint transport errors and HTTP-level failures into a
  consistent struct.
  """

  defstruct [:reason, :message, :status]

  @type t :: %__MODULE__{
          reason: atom() | term(),
          message: String.t() | nil,
          status: pos_integer() | nil
        }

  @doc false
  def wrap(reason, message \\ nil, status \\ nil) do
    %__MODULE__{reason: reason, message: message, status: status}
  end

  @doc false
  def timeout do
    %__MODULE__{reason: :timeout, message: "request timed out"}
  end

  @doc false
  def connection_refused do
    %__MODULE__{reason: :econnrefused, message: "connection refused"}
  end

  @doc false
  def from_finch_error(%Finch.Error{reason: reason}) do
    %__MODULE__{reason: reason, message: "Finch error: #{inspect(reason)}"}
  end

  def from_finch_error(%Mint.TransportError{reason: reason}) do
    %__MODULE__{reason: reason, message: "Transport error: #{reason}"}
  end

  def from_finch_error(%{__struct__: mod} = error)
      when mod in [Finch.TransportError, Finch.HTTPError] do
    %__MODULE__{reason: error.reason, message: Exception.message(error)}
  end

  def from_finch_error(exception) do
    %__MODULE__{reason: exception.__struct__, message: Exception.message(exception)}
  end
end
