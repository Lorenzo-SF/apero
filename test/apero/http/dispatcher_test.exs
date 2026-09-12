defmodule Apero.HttpTest.MockAdapter do
  @behaviour Apero.Http.Adapter

  @impl true
  def request(%{method: method} = req) do
    {:ok,
     %Apero.Http.Response{
       status: 200,
       headers: [{"content-type", "application/json"}],
       body: %{method: method, url: req.url}
     }}
  end

  @impl true
  def stream(%{method: method} = req, acc, fun, _opts) do
    resp = %Apero.Http.Response{status: 200, headers: [], body: nil}
    acc = apply_entry(fun, {:status, resp.status}, acc)
    acc = apply_entry(fun, {:data, "chunk-#{method}-#{req.url}"}, acc)
    {:ok, acc}
  end

  defp apply_entry(fun, entry, acc) do
    case fun.(entry, acc) do
      {:cont, new_acc} -> new_acc
      {:halt, new_acc} -> new_acc
    end
  end
end

defmodule Apero.HttpTest.DispatcherTest do
  use ExUnit.Case

  alias Apero.Http
  alias Apero.Http.Response

  alias Apero.Http.Method.{Delete, Get, Patch, Post, Put, Query}

  setup do
    Application.put_env(:apero, :http_adapter, Apero.HttpTest.MockAdapter)
    on_exit(fn -> Application.delete_env(:apero, :http_adapter) end)
    :ok
  end

  describe "Apero.Http dispatcher" do
    test "get/3 returns a response" do
      assert {:ok, %Response{status: 200, body: %{method: :get}}} =
               Http.get("https://example.com")
    end

    test "post/4 sends body" do
      assert {:ok, %Response{body: %{method: :post}}} =
               Http.post("https://example.com", %{a: 1})
    end

    test "put/4" do
      assert {:ok, %Response{body: %{method: :put}}} = Http.put("https://example.com", "x")
    end

    test "patch/4" do
      assert {:ok, %Response{body: %{method: :patch}}} =
               Http.patch("https://example.com", "x")
    end

    test "delete/3" do
      assert {:ok, %Response{body: %{method: :delete}}} = Http.delete("https://example.com")
    end

    test "query/4" do
      assert {:ok, %Response{body: %{method: :query}}} =
               Http.query("https://example.com", nil)
    end

    test "request/5 raw dispatch" do
      assert {:ok, %Response{body: %{method: :get}}} =
               Http.request(:get, "https://example.com", nil)
    end

    test "request/5 raises on unsupported method" do
      assert_raise ArgumentError, fn ->
        Http.request(:head, "https://example.com", nil)
      end
    end

    test "stream/7 collects chunks" do
      assert {:ok, acc} =
               Http.stream(:get, "https://example.com", nil, [], [], fn entry, acc ->
                 case entry do
                   {:status, s} -> {:cont, [s | acc]}
                   {:data, d} -> {:cont, [d | acc]}
                   {:done, _} -> {:halt, acc}
                 end
               end)

      assert Enum.reverse(acc) == [200, "chunk-get-https://example.com"]
    end
  end

  describe "Apero.Http.Method builders" do
    test "each builder produces the right method/url" do
      assert %{method: :get, url: "u"} = Get.build(url: "u")
      assert %{method: :post, url: "u"} = Post.build(url: "u")
      assert %{method: :put, url: "u"} = Put.build(url: "u")
      assert %{method: :patch, url: "u"} = Patch.build(url: "u")
      assert %{method: :delete, url: "u"} = Delete.build(url: "u")
      assert %{method: :query, url: "u"} = Query.build(url: "u")
    end
  end

  describe "Apero.Http structs" do
    test "Request struct" do
      req = %Apero.Http.Request{method: :get, url: "u", headers: [], body: nil, options: []}
      assert req.method == :get
      assert req.url == "u"
    end

    test "Response struct" do
      resp = %Apero.Http.Response{status: 200, headers: [], body: "ok"}
      assert resp.status == 200
      assert resp.body == "ok"
    end
  end
end
