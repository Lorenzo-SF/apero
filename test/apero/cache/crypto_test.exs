defmodule Apero.Cache.CryptoTest do
  alias Apero.Cache.Crypto
  use ExUnit.Case
  doctest Apero.Cache.Crypto

  setup_all do
    # Ensure the application is started so supervision tree launches the cache
    Application.ensure_all_started(:apero)
    :ok
  end

  @tag :cache
  test "sha256 is memoised" do
    data = "foo"
    first = Crypto.sha256(data)
    second = Crypto.sha256(data)
    assert first == second

    # ETS entry exists
    [{{:sha256, ^data}, ^first}] = :ets.lookup(:apero_cache_crypto, {:sha256, data})
  end

  @tag :cache
  test "sha512 is memoised" do
    data = "bar"
    first = Crypto.sha512(data)
    second = Crypto.sha512(data)
    assert first == second
    [{{:sha512, ^data}, ^first}] = :ets.lookup(:apero_cache_crypto, {:sha512, data})
  end

  @tag :cache
  test "md5 is memoised" do
    data = "baz"
    first = Crypto.md5(data)
    second = Crypto.md5(data)
    assert first == second
    [{{:md5, ^data}, ^first}] = :ets.lookup(:apero_cache_crypto, {:md5, data})
  end
end
