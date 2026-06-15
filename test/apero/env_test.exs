defmodule Apero.EnvTest do
  # async: false — modifies global env vars (System.put_env), unsafe for parallel execution
  use ExUnit.Case, async: false

  alias Apero.Env

  @tmp_env Path.join(System.tmp_dir!(), "apero_test_#{:rand.uniform(999_999)}.env")

  setup do
    on_exit(fn -> File.rm(@tmp_env) end)
    :ok
  end

  describe "load/1" do
    test "loads key-value pairs into process environment" do
      File.write!(@tmp_env, "APERO_TEST_VAR=hello\nAPERO_TEST_NUM=42\n")
      assert {:ok, vars} = Env.load(@tmp_env)
      assert vars["APERO_TEST_VAR"] == "hello"
      assert vars["APERO_TEST_NUM"] == "42"
      assert System.get_env("APERO_TEST_VAR") == "hello"
    end

    test "ignores comments and blank lines" do
      File.write!(@tmp_env, "# comment\n\nAPERO_REAL=yes\n")
      assert {:ok, vars} = Env.load(@tmp_env)
      refute Map.has_key?(vars, "# comment")
      assert vars["APERO_REAL"] == "yes"
    end

    test "supports export prefix" do
      File.write!(@tmp_env, "export APERO_EXPORTED=1\n")
      assert {:ok, vars} = Env.load(@tmp_env)
      assert vars["APERO_EXPORTED"] == "1"
    end

    test "strips surrounding quotes from values" do
      File.write!(@tmp_env, ~s(APERO_Q="quoted value"\n))
      assert {:ok, vars} = Env.load(@tmp_env)
      assert vars["APERO_Q"] == "quoted value"
    end

    test "returns error for missing file" do
      assert {:error, _} = Env.load("/nonexistent/path/.env")
    end
  end

  describe "read/1" do
    test "parses without modifying env" do
      key = "APERO_READ_ONLY_#{:rand.uniform(9999)}"
      File.write!(@tmp_env, "#{key}=readonly\n")
      assert {:ok, vars} = Env.read(@tmp_env)
      assert vars[key] == "readonly"
      assert System.get_env(key) == nil
    end
  end

  describe "write/2" do
    test "writes vars to file and can be read back" do
      vars = %{"APERO_WRITE_A" => "foo", "APERO_WRITE_B" => "bar"}
      assert :ok = Env.write(@tmp_env, vars)
      assert {:ok, read_back} = Env.read(@tmp_env)
      assert read_back["APERO_WRITE_A"] == "foo"
      assert read_back["APERO_WRITE_B"] == "bar"
    end
  end

  describe "get_as/2" do
    setup do
      System.put_env("APERO_INT", "42")
      System.put_env("APERO_FLOAT", "3.14")
      System.put_env("APERO_BOOL_T", "true")
      System.put_env("APERO_BOOL_F", "false")
      System.put_env("APERO_STR", "hello")

      on_exit(fn ->
        Enum.each(
          ~w[APERO_INT APERO_FLOAT APERO_BOOL_T APERO_BOOL_F APERO_STR],
          &System.delete_env/1
        )
      end)

      :ok
    end

    test "casts to integer" do
      assert {:ok, 42} = Env.get_as("APERO_INT", :integer)
    end

    test "casts to float" do
      assert {:ok, 3.14} = Env.get_as("APERO_FLOAT", :float)
    end

    test "casts true" do
      assert {:ok, true} = Env.get_as("APERO_BOOL_T", :boolean)
    end

    test "casts false" do
      assert {:ok, false} = Env.get_as("APERO_BOOL_F", :boolean)
    end

    test "returns string" do
      assert {:ok, "hello"} = Env.get_as("APERO_STR", :string)
    end

    test "returns error for unset variable" do
      assert {:error, _} = Env.get_as("APERO_UNSET_XXXXXX", :integer)
    end
  end

  describe "require_keys/1" do
    test "returns ok with all present keys" do
      System.put_env("APERO_REQ_A", "a")
      System.put_env("APERO_REQ_B", "b")
      on_exit(fn -> Enum.each(~w[APERO_REQ_A APERO_REQ_B], &System.delete_env/1) end)

      assert {:ok, %{"APERO_REQ_A" => "a", "APERO_REQ_B" => "b"}} =
               Env.require_keys(["APERO_REQ_A", "APERO_REQ_B"])
    end

    test "returns error with missing keys" do
      assert {:error, missing} = Env.require_keys(["APERO_DEFINITELY_NOT_SET_XYZ"])
      assert "APERO_DEFINITELY_NOT_SET_XYZ" in missing
    end
  end
end
