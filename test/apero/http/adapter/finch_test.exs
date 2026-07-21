defmodule Apero.Http.Adapter.FinchTest.UnencodableStruct do
  defstruct [:data]
end

defmodule Apero.Http.Adapter.FinchTest do
  use ExUnit.Case, async: false

  alias Apero.Http.Adapter.Finch
  alias Apero.Http.Request
  alias Plug.Conn

  setup do
    Apero.Http.Finch.ensure_started()
    :ok
  end

  describe "request/1" do
    test "sends a GET request and decodes JSON response" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, ~s({"status":"ok"}))
      end)

      req = %Request{
        method: :get,
        url: "http://localhost:#{bypass.port}/test",
        headers: [],
        body: nil,
        options: [receive_timeout: 5000, pool_timeout: 5000]
      }

      assert {:ok, resp} = Finch.request(req)
      assert resp.status == 200
      assert resp.body == %{"status" => "ok"}
    end

    test "sends a POST request with JSON body" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        {:ok, body, _} = Conn.read_body(conn)
        assert body =~ "hello"

        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(201, ~s({"created":true}))
      end)

      req = %Request{
        method: :post,
        url: "http://localhost:#{bypass.port}/create",
        headers: [],
        body: %{msg: "hello"},
        options: [receive_timeout: 5000, pool_timeout: 5000]
      }

      assert {:ok, resp} = Finch.request(req)
      assert resp.status == 201
      assert resp.body == %{"created" => true}
    end

    test "handles text/plain response without JSON decoding" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.put_resp_content_type("text/plain")
        |> Conn.resp(200, "plain text response")
      end)

      req = %Request{
        method: :get,
        url: "http://localhost:#{bypass.port}/text",
        headers: [],
        body: nil,
        options: [receive_timeout: 5000, pool_timeout: 5000]
      }

      assert {:ok, resp} = Finch.request(req)
      assert resp.status == 200
      assert resp.body == "plain text response"
    end

    test "returns {:error, _} on connection refused" do
      Apero.Http.Finch.ensure_started()

      req = %Request{
        method: :get,
        url: "http://localhost:1",
        headers: [],
        body: nil,
        options: [receive_timeout: 1000, pool_timeout: 1000]
      }

      result = Finch.request(req)

      assert match?({:error, _}, result)
    end

    test "returns {:error, _} for non-encodable body" do
      Apero.Http.Finch.ensure_started()

      req = %Request{
        method: :post,
        url: "http://localhost:29999",
        headers: [],
        body: %Apero.Http.Adapter.FinchTest.UnencodableStruct{data: "test"},
        options: [receive_timeout: 1000, pool_timeout: 1000]
      }

      assert {:error, _} = Finch.request(req)
    end
  end

  describe "stream/4" do
    test "streams a response via callback returning {:ok, acc}" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, ~s({"chunked":true}))
      end)

      req = %Request{
        method: :get,
        url: "http://localhost:#{bypass.port}/stream",
        headers: [],
        body: nil,
        options: [receive_timeout: 5000, pool_timeout: 5000]
      }

      result =
        Finch.stream(
          req,
          [],
          fn
            {:data, chunk}, acc -> {[chunk | acc], :cont}
            {:done, _}, acc -> {acc, :halt}
            _, acc -> {acc, :cont}
          end,
          receive_timeout: 5000,
          pool_timeout: 5000
        )

      assert {:ok, _acc} = result
    end
  end
end
