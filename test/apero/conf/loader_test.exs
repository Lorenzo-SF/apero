defmodule Apero.Conf.LoaderTest do
  use ExUnit.Case, async: true

  alias Apero.Conf.Loader

  describe "deep_merge/2" do
    test "merges two flat maps" do
      defaults = %{a: 1, b: 2}
      overrides = %{b: 3, c: 4}
      assert Loader.deep_merge(defaults, overrides) == %{a: 1, b: 3, c: 4}
    end

    test "recursively merges nested maps" do
      defaults = %{a: %{x: 1, y: 2}, b: 3}
      overrides = %{a: %{y: 20, z: 30}, c: 4}

      assert Loader.deep_merge(defaults, overrides) ==
               %{a: %{x: 1, y: 20, z: 30}, b: 3, c: 4}
    end

    test "does not mutate inputs" do
      defaults = %{a: %{x: 1}}
      overrides = %{a: %{y: 2}}

      Loader.deep_merge(defaults, overrides)

      assert defaults == %{a: %{x: 1}}
      assert overrides == %{a: %{y: 2}}
    end

    test "overrides win for non-map values" do
      defaults = %{a: "default"}
      overrides = %{a: "override"}
      assert Loader.deep_merge(defaults, overrides) == %{a: "override"}
    end

    test "returns defaults when overrides is empty" do
      defaults = %{a: 1, b: 2}
      assert Loader.deep_merge(defaults, %{}) == defaults
    end
  end

  describe "load/2 with :defaults" do
    test "deep-merges defaults with loaded JSON" do
      path = Path.join(System.tmp_dir(), "apero-loader-#{System.unique_integer([:positive])}.json")
      File.write!(path, ~s({"b": 2, "c": 3}))

      defaults = %{a: 1, b: 0}

      assert {:ok, %{a: 1, b: 2, c: 3}} =
               Loader.load(path, defaults: defaults)
    end

    test "without :defaults, returns loaded config as-is" do
      path = Path.join(System.tmp_dir(), "apero-loader-#{System.unique_integer([:positive])}.json")
      File.write!(path, ~s({"a": 1}))

      assert {:ok, %{"a" => 1}} = Loader.load(path)
    end

    test "returns error for missing file" do
      path = "/tmp/nonexistent-#{System.unique_integer([:positive])}.json"
      assert {:error, :enoent} = Loader.load(path)
    end
  end
end
