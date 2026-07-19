defmodule Apero.Http.Adapter.Finch do
  @moduledoc """
  HTTP adapter that uses Finch for transport.

  Converts `Apero.Http.Request` to/from Finch's internal request format.
  Uses `Apero.Http.Finch` as the named Finch instance.
  """

  @behaviour Apero.Http.Adapter

  @impl true
  def request(%Apero.Http.Request{} = req) do
    Apero.Http.Finch.ensure_started()

    with {:ok, finch_req} <- to_finch_request(req) do
      finch_opts = to_finch_opts(req.options)

      case Finch.request(finch_req, Apero.Http.Finch, finch_opts) do
        {:ok, %Finch.Response{} = finch_resp} ->
          {:ok, to_finch_response(finch_resp)}

        {:error, exception} ->
          {:error, Apero.Http.Error.from_finch_error(exception)}
      end
    end
  end

  @impl true
  def stream(%Apero.Http.Request{} = req, acc, fun, opts \\ []) do
    Apero.Http.Finch.ensure_started()

    with {:ok, finch_req} <- to_finch_request(req) do
      finch_opts = to_finch_opts(opts, :stream)

      case Finch.stream(finch_req, Apero.Http.Finch, acc, fun, finch_opts) do
        {:ok, acc} ->
          {:ok, acc}

        {:error, exception} ->
          {:error, Apero.Http.Error.from_finch_error(exception)}

        {:error, exception, _acc} ->
          {:error, Apero.Http.Error.from_finch_error(exception)}
      end
    end
  end

  # ── Internals ────────────────────────────────────────────────────────────

  defp to_finch_request(%Apero.Http.Request{
         method: method,
         url: url,
         headers: headers,
         body: body
       }) do
    method = String.upcase(Atom.to_string(method))

    with {:ok, finch_body} <- encode_body(body) do
      {:ok, Finch.build(method, url, headers, finch_body)}
    end
  end

  defp encode_body(body) when is_map(body) or is_list(body), do: Jason.encode(body)
  defp encode_body(body), do: {:ok, body}

  defp to_finch_response(%Finch.Response{status: status, headers: headers, body: body}) do
    decoded_body = maybe_decode_json(body, headers)
    %Apero.Http.Response{status: status, headers: headers, body: decoded_body}
  end

  defp maybe_decode_json(body, headers) do
    if json_content_type?(headers) do
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        {:error, _} -> body
      end
    else
      body
    end
  end

  defp json_content_type?(headers) do
    Enum.any?(headers, fn
      {"content-type", value} -> String.contains?(value, "json")
      {_, _} -> false
    end)
  end

  defp to_finch_opts(opts) do
    timeout = Keyword.get(opts, :receive_timeout, 30_000)
    pool_timeout = Keyword.get(opts, :pool_timeout, 5_000)
    [receive_timeout: timeout, pool_timeout: pool_timeout]
  end

  defp to_finch_opts(opts, :stream) do
    timeout = Keyword.get(opts, :receive_timeout, 30_000)
    pool_timeout = Keyword.get(opts, :pool_timeout, 5_000)
    [receive_timeout: timeout, pool_timeout: pool_timeout]
  end
end
