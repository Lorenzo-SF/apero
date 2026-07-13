defmodule Apero.HttpTest do
  use ExUnit.Case, async: true

  alias Apero.Http.{Request, Response, Error}

  describe "Request struct" do
    test "builds a basic request with required fields" do
      req = %Request{
        method: :get,
        url: "https://example.com",
        headers: [],
        body: nil,
        options: []
      }

      assert req.method == :get
      assert req.url == "https://example.com"
      assert req.headers == []
      assert req.body == nil
    end
  end

  describe "Response struct" do
    test "has status, headers, and body fields" do
      resp = %Response{
        status: 200,
        headers: [{"content-type", "application/json"}],
        body: %{"key" => "value"}
      }

      assert resp.status == 200
      assert is_list(resp.headers)
      assert is_map(resp.body)
    end
  end

  describe "Error struct" do
    test "wraps an arbitrary reason" do
      err = Error.wrap(:timeout, "request timed out", nil)

      assert err.reason == :timeout
      assert err.message == "request timed out"
      assert err.status == nil
    end

    test "from_finch_error handles Finch.Error" do
      err = %Finch.Error{reason: :connection_closed}
      wrapped = Error.from_finch_error(err)

      assert wrapped.reason == :connection_closed
    end

    test "from_finch_error handles Mint.TransportError" do
      err = %Mint.TransportError{reason: :econnrefused}
      wrapped = Error.from_finch_error(err)

      assert wrapped.reason == :econnrefused
      assert wrapped.message =~ "Transport error"
    end

    test "from_finch_error handles Finch.TransportError" do
      err = %Finch.TransportError{reason: :nxdomain}
      wrapped = Error.from_finch_error(err)

      assert wrapped.reason == :nxdomain
    end

    test "from_finch_error handles Finch.HTTPError" do
      err = %Finch.HTTPError{module: Mint.HTTP1, reason: {:bad_response, "error"}}
      wrapped = Error.from_finch_error(err)

      assert wrapped.reason == {:bad_response, "error"}
    end

    test "from_finch_error handles generic exception" do
      err = %RuntimeError{message: "something went wrong"}
      wrapped = Error.from_finch_error(err)

      assert wrapped.reason == RuntimeError
      assert wrapped.message == "something went wrong"
    end

    test "timeout/0 factory" do
      err = Error.timeout()

      assert err.reason == :timeout
      assert err.message =~ "timed out"
    end

    test "connection_refused/0 factory" do
      err = Error.connection_refused()

      assert err.reason == :econnrefused
      assert err.message =~ "connection refused"
    end
  end

  describe "Method behaviour" do
    test "all built-in methods implement the behaviour" do
      methods = [
        Apero.Http.Method.Get,
        Apero.Http.Method.Post,
        Apero.Http.Method.Put,
        Apero.Http.Method.Patch,
        Apero.Http.Method.Delete,
        Apero.Http.Method.Query
      ]

      for module <- methods do
        assert Code.ensure_loaded?(module)
        assert function_exported?(module, :build, 1)

        assert module.build(url: "http://x").method in [
                 :get,
                 :post,
                 :put,
                 :patch,
                 :delete,
                 :query
               ]
      end
    end
  end

  describe "Get.build/1" do
    test "builds a request with method :get and no body" do
      req = Apero.Http.Method.Get.build(url: "https://example.com", headers: [{"x", "y"}])

      assert req.method == :get
      assert req.url == "https://example.com"
      assert req.headers == [{"x", "y"}]
      assert req.body == nil
    end
  end

  describe "Post.build/1" do
    test "builds a request with method :post and body" do
      body = %{key: "value"}

      req = Apero.Http.Method.Post.build(url: "https://example.com", body: body)

      assert req.method == :post
      assert req.body == body
    end

    test "accepts a body of nil" do
      req = Apero.Http.Method.Post.build(url: "https://example.com")

      assert req.method == :post
      assert req.body == nil
    end
  end

  describe "Put.build/1" do
    test "builds a request with method :put" do
      req = Apero.Http.Method.Put.build(url: "https://example.com", body: %{a: 1})

      assert req.method == :put
      assert req.body == %{a: 1}
    end
  end

  describe "Patch.build/1" do
    test "builds a request with method :patch" do
      req = Apero.Http.Method.Patch.build(url: "https://example.com", body: %{a: 1})

      assert req.method == :patch
    end
  end

  describe "Delete.build/1" do
    test "builds a request with method :delete and no body by default" do
      req = Apero.Http.Method.Delete.build(url: "https://example.com")

      assert req.method == :delete
      assert req.body == nil
    end

    test "accepts an optional body" do
      req =
        Apero.Http.Method.Delete.build(url: "https://example.com", body: %{reason: "obsolete"})

      assert req.body == %{reason: "obsolete"}
    end
  end

  describe "Query.build/1" do
    test "builds a request with method :query and body" do
      req = Apero.Http.Method.Query.build(url: "https://example.com", body: %{q: "search"})

      assert req.method == :query
      assert req.body == %{q: "search"}
    end
  end

  describe "Adapter behaviour" do
    test "default adapter is Finch" do
      assert Application.get_env(:apero, :http_adapter, Apero.Http.Adapter.Finch) ==
               Apero.Http.Adapter.Finch
    end
  end

  describe "Finch lifecycle" do
    test "ensure_started/0 is idempotent and returns :ok" do
      assert :ok = Apero.Http.Finch.ensure_started()
      assert :ok = Apero.Http.Finch.ensure_started()
      assert Process.whereis(Apero.Http.Finch) != nil
    end
  end
end
