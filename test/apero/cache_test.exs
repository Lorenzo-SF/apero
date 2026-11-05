defmodule Apero.CacheTest do
  use ExUnit.Case, async: true

  alias Apero.Cache

  setup do
    # credo:disable-for-next-line
    name = :"test_cache_#{System.unique_integer([:positive])}"

    {:ok, pid} = Cache.start_link(Apero.Cache.ETS, name: name)

    {:ok, %{cache: pid, name: name}}
  end

  describe "start_link/2" do
    test "creates a cache with a name and returns {:ok, pid}" do
      # credo:disable-for-next-line
      name = :"test_start_link_#{System.unique_integer([:positive])}"

      assert {:ok, pid} = Cache.start_link(Apero.Cache.ETS, name: name)
      assert is_pid(pid)
      assert Process.whereis(name) == pid
    end
  end

  describe "put/4 and get/2" do
    test "stores and retrieves a value", %{cache: cache} do
      assert :ok = Cache.put(cache, "key", "value")
      assert {:ok, "value"} = Cache.get(cache, "key")
    end

    test "stores and retrieves different data types", %{cache: cache} do
      assert :ok = Cache.put(cache, :atom_key, :atom_value)
      assert {:ok, :atom_value} = Cache.get(cache, :atom_key)

      assert :ok = Cache.put(cache, 42, %{nested: "map"})
      assert {:ok, %{nested: "map"}} = Cache.get(cache, 42)

      assert :ok = Cache.put(cache, "list", [1, 2, 3])
      assert {:ok, [1, 2, 3]} = Cache.get(cache, "list")
    end

    test "overwrites existing key with new value", %{cache: cache} do
      Cache.put(cache, "key", "old_value")
      Cache.put(cache, "key", "new_value")
      assert {:ok, "new_value"} = Cache.get(cache, "key")
    end
  end

  describe "get/2" do
    test "returns {:error, :not_found} for missing key", %{cache: cache} do
      assert {:error, :not_found} = Cache.get(cache, "nonexistent")
    end

    test "returns {:error, :not_found} after key is deleted", %{cache: cache} do
      Cache.put(cache, "ephemeral", "data")
      Cache.delete(cache, "ephemeral")
      assert {:error, :not_found} = Cache.get(cache, "ephemeral")
    end
  end

  describe "put/4 with TTL" do
    @tag :timing
    test "value expires after the specified TTL", %{cache: cache} do
      assert :ok = Cache.put(cache, "ephemeral", "data", ttl: 1)
      assert {:ok, "data"} = Cache.get(cache, "ephemeral")

      Process.sleep(2000)

      assert {:error, :not_found} = Cache.get(cache, "ephemeral")
    end

    test "value persists before TTL expires", %{cache: cache} do
      assert :ok = Cache.put(cache, "sticky", "data", ttl: 60)
      assert {:ok, "data"} = Cache.get(cache, "sticky")
    end

    test "defaults to 3600s TTL when no ttl option given", %{cache: cache} do
      assert :ok = Cache.put(cache, "persistent", "data")
      assert {:ok, "data"} = Cache.get(cache, "persistent")
    end
  end

  describe "delete/2" do
    test "removes an existing key", %{cache: cache} do
      Cache.put(cache, "delete_me", "value")
      assert :ok = Cache.delete(cache, "delete_me")
      assert {:error, :not_found} = Cache.get(cache, "delete_me")
    end

    test "is idempotent when removing a non-existent key", %{cache: cache} do
      assert :ok = Cache.delete(cache, "already_gone")
    end
  end

  describe "fetch/4" do
    test "returns existing cached value without calling the function", %{cache: cache} do
      Cache.put(cache, "cached", "stored_value")

      fun = fn -> raise "should not be called" end

      assert {:ok, "stored_value"} = Cache.fetch(cache, "cached", fun)
    end

    test "calls the generator function, stores and returns its result on cache miss", %{
      cache: cache
    } do
      assert {:ok, "computed"} = Cache.fetch(cache, "computed", fn -> "computed" end)
      assert {:ok, "computed"} = Cache.get(cache, "computed")
    end

    test "stores fetched value with custom TTL", %{cache: cache} do
      assert {:ok, "data"} = Cache.fetch(cache, "ttl_fetched", fn -> "data" end, ttl: 1)

      Process.sleep(2000)

      assert {:error, :not_found} = Cache.get(cache, "ttl_fetched")
    end

    test "does not call generator on subsequent fetches after cache hit", %{cache: cache} do
      Cache.fetch(cache, "lazy", fn -> "initial" end)

      assert {:ok, "initial"} =
               Cache.fetch(cache, "lazy", fn ->
                 raise "generator should not be called on cache hit"
               end)
    end
  end

  describe "flush/1" do
    test "clears all keys from the cache", %{cache: cache} do
      Cache.put(cache, :a, 1)
      Cache.put(cache, :b, 2)
      Cache.put(cache, :c, 3)

      assert :ok = Cache.flush(cache)

      assert {:error, :not_found} = Cache.get(cache, :a)
      assert {:error, :not_found} = Cache.get(cache, :b)
      assert {:error, :not_found} = Cache.get(cache, :c)
    end

    test "flush on empty cache returns :ok", %{cache: cache} do
      assert :ok = Cache.flush(cache)
    end
  end

  describe "size/1" do
    test "returns zero for an empty cache", %{cache: cache} do
      assert {:ok, 0} = Cache.size(cache)
    end

    test "returns the number of stored entries", %{cache: cache} do
      Cache.put(cache, :a, 1)
      Cache.put(cache, :b, 2)
      assert {:ok, 2} = Cache.size(cache)
    end

    test "decreases after deleting a key", %{cache: cache} do
      Cache.put(cache, :a, 1)
      Cache.put(cache, :b, 2)
      Cache.delete(cache, :a)
      assert {:ok, 1} = Cache.size(cache)
    end

    test "returns zero after flush", %{cache: cache} do
      Cache.put(cache, :a, 1)
      Cache.put(cache, :b, 2)
      Cache.flush(cache)
      assert {:ok, 0} = Cache.size(cache)
    end
  end

  describe "member?/2" do
    test "returns true when key exists", %{cache: cache} do
      Cache.put(cache, :existing, "value")
      assert Cache.member?(cache, :existing)
    end

    test "returns false when key does not exist", %{cache: cache} do
      refute Cache.member?(cache, :nonexistent)
    end

    test "returns false after key is deleted", %{cache: cache} do
      Cache.put(cache, "temp", "value")
      Cache.delete(cache, "temp")
      refute Cache.member?(cache, "temp")
    end

    test "returns false for expired TTL entries", %{cache: cache} do
      Cache.put(cache, "expirable", "data", ttl: 1)
      assert Cache.member?(cache, "expirable")
      Process.sleep(2500)
      refute Cache.member?(cache, "expirable")
    end
  end

  describe "facade delegation with pid vs atom" do
    test "works with both pid and atom name", %{cache: cache, name: name} do
      Cache.put(name, :key, "via_atom")
      assert {:ok, "via_atom"} = Cache.get(cache, :key)

      Cache.put(cache, :key2, "via_pid")
      assert {:ok, "via_pid"} = Cache.get(name, :key2)
    end
  end
end
