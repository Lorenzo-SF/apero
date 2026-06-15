defmodule Apero.ConfTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Apero.Conf

  describe "detect_format/1" do
    test "detects .json as :json" do
      assert Conf.detect_format("config.json") == :json
      assert Conf.detect_format("config.JSON") == :json
    end

    test "detects .yaml as :yaml" do
      assert Conf.detect_format("config.yaml") == :yaml
    end

    test "detects .yml as :yaml" do
      assert Conf.detect_format("config.yml") == :yaml
    end

    test "detects .toml as :toml" do
      assert Conf.detect_format("config.toml") == :toml
    end

    test "defaults to :json for unknown extension" do
      assert Conf.detect_format("config.unknown") == :json
      assert Conf.detect_format("Makefile") == :json
    end

    test "handles paths with nested directories" do
      assert Conf.detect_format("/etc/apero/settings.json") == :json
      assert Conf.detect_format("~/.config/app/config.yaml") == :yaml
    end
  end

  describe "validate/2" do
    test "returns :ok when config matches schema" do
      config = %{"name" => "test", "port" => 8080, "enabled" => true}
      schema = %{"name" => :string, "port" => :integer, "enabled" => :boolean}

      assert Conf.validate(config, schema) == :ok
    end

    test "returns error for missing required key" do
      config = %{"name" => "test"}
      schema = %{"name" => :string, "port" => :integer}

      assert {:error, errors} = Conf.validate(config, schema)
      assert Enum.any?(errors, &String.contains?(&1, "Missing required key: port"))
    end

    test "returns error for type mismatch" do
      config = %{"name" => 42}
      schema = %{"name" => :string}

      assert {:error, errors} = Conf.validate(config, schema)
      assert Enum.any?(errors, &String.contains?(&1, "name: expected string, got integer"))
    end

    test "accepts :any type for any value" do
      config = %{"key" => :arbitrary_atom}
      schema = %{"key" => :any}

      assert Conf.validate(config, schema) == :ok
    end

    test "accepts float for :float type" do
      config = %{"pi" => 3.14, "answer" => 42}
      schema = %{"pi" => :float, "answer" => :float}

      assert Conf.validate(config, schema) == :ok
    end

    test "returns :ok for empty schema" do
      assert Conf.validate(%{}, %{}) == :ok
    end

    test "accumulates multiple errors" do
      config = %{"a" => 1}
      schema = %{"a" => :string, "b" => :integer, "c" => :boolean}

      assert {:error, errors} = Conf.validate(config, schema)
      assert length(errors) >= 2
    end
  end

  describe "encode/2" do
    test "encodes a map to pretty JSON" do
      data = %{"name" => "test", "nested" => %{"key" => "val"}}

      assert {:ok, json} = Conf.encode(data, :json)
      assert json =~ ~S{"name": "test"}
      assert json =~ ~S{"nested":}
      assert json =~ ~S{"key": "val"}
    end

    test "returns error for yaml encoding" do
      assert {:error, msg} = Conf.encode(%{}, :yaml)
      assert msg =~ "yaml"
    end

    test "encodes toml correctly" do
      assert {:ok, toml} = Conf.encode(%{key: "val"}, :toml)
      assert toml =~ ~S{key = "val"}
    end

    test "handles empty map" do
      assert {:ok, "{}"} = Conf.encode(%{}, :json)
    end
  end

  describe "load/2" do
    test "loads a JSON file" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "test_conf_#{System.unique_integer([:positive])}.json")
      File.write!(path, ~s({"key": "value"}))
      on_exit(fn -> File.rm(path) end)

      assert {:ok, config} = Conf.load(path, format: :json)
      assert config["key"] == "value"
    end

    test "returns error for missing file" do
      assert {:error, _} = Conf.load("/nonexistent/path.json", format: :json)
    end
  end

  describe "write/3" do
    test "writes a JSON file" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "test_write_#{System.unique_integer([:positive])}.json")
      on_exit(fn -> File.rm(path) end)

      assert :ok = Conf.write(path, %{a: 1}, format: :json)
      assert File.exists?(path)
      assert {:ok, content} = File.read(path)
      assert content =~ ~s("a")
    end
  end

  describe "merge/1" do
    test "merges multiple configs" do
      a = %{"key1" => "val1"}
      b = %{"key2" => "val2"}

      merged = Conf.merge([a, b])
      assert merged["key1"] == "val1"
      assert merged["key2"] == "val2"
    end

    test "later configs override earlier ones" do
      a = %{"key" => "old"}
      b = %{"key" => "new"}

      assert Conf.merge([a, b])["key"] == "new"
    end
  end

  describe "print_summary/2" do
    test "prints config summary" do
      config = %{"app_name" => "test", "version" => 1}

      capture =
        capture_io(fn ->
          Conf.print_summary(config, "Test Config")
        end)

      assert capture =~ "Test Config"
      assert capture =~ "app_name"
    end
  end

  describe "get/2" do
    test "gets a top-level key" do
      assert Conf.get(%{foo: 1}, "foo") == 1
    end

    test "gets a nested key" do
      assert Conf.get(%{a: %{b: 2}}, "a.b") == 2
    end

    test "returns nil for missing key" do
      assert is_nil(Conf.get(%{foo: 1}, "bar"))
    end
  end

  describe "set/3" do
    test "sets a top-level key" do
      assert Conf.set(%{foo: 1}, "foo", 2) == %{foo: 2}
    end

    test "sets a nested key" do
      assert Conf.set(%{a: %{b: 1}}, "a.b", 2) == %{a: %{b: 2}}
    end

    test "returns new map without mutating original" do
      original = %{foo: 1}
      new = Conf.set(original, "foo", 2)
      assert original == %{foo: 1}
      assert new == %{foo: 2}
    end
  end

  describe "encode/2 toml" do
    test "encodes flat map" do
      {:ok, toml} = Conf.encode(%{name: "test", count: 42}, :toml)
      assert toml =~ ~S{name = "test"}
      assert toml =~ ~S{count = 42}
    end

    test "encodes nested map with sections" do
      {:ok, toml} = Conf.encode(%{section: %{key: "val"}}, :toml)
      assert toml =~ ~S{[section]}
      assert toml =~ ~S{key = "val"}
    end

    test "encodes arrays" do
      {:ok, toml} = Conf.encode(%{tags: ["a", "b"]}, :toml)
      assert toml =~ ~S{tags = [}
    end
  end
end
