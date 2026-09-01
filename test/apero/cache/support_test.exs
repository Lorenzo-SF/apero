defmodule Apero.Cache.SupportTest do
  use ExUnit.Case, async: true

  describe "Apero.Cache.Adapter behaviour" do
    test "behaviour callbacks are defined" do
      callbacks = Apero.Cache.Adapter.behaviour_info(:callbacks)
      names = Enum.map(callbacks, fn {name, _arity} -> name end)
      assert :start_link in names
      assert :put in names
      assert :get in names
      assert :delete in names
      assert :flush in names
      assert :size in names
      assert :member? in names
    end

    test "behaviour is compilable by an implementor" do
      defmodule AdapterImpl do
        @behaviour Apero.Cache.Adapter

        @impl true
        def start_link(_opts), do: {:ok, self()}

        @impl true
        def put(_adapter, _key, _value, _opts), do: :ok

        @impl true
        def get(_adapter, _key), do: {:error, :not_found}

        @impl true
        def delete(_adapter, _key), do: :ok

        @impl true
        def flush(_adapter), do: :ok

        @impl true
        def size(_adapter), do: {:ok, 0}

        @impl true
        def member?(_adapter, _key), do: false
      end

      assert {:ok, _} = AdapterImpl.start_link([])
      assert AdapterImpl.member?(self(), :k) == false
    end
  end

  describe "Apero.Cache.Supervisor" do
    test "start_link/1 boots the supervisor" do
      assert {:ok, pid} = Apero.Cache.Supervisor.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
