defmodule Apero.KubernetesTest do
  use ExUnit.Case, async: true

  alias Apero.Kubernetes

  @moduletag :external_cmd

  describe "available?/0" do
    test "returns a boolean" do
      result = Kubernetes.available?()
      assert is_boolean(result)
    end
  end

  describe "function signatures" do
    test "pods/2 is defined" do
      Code.ensure_loaded(Kubernetes)
      assert function_exported?(Kubernetes, :pods, 2)
    end

    test "apply/2 is defined" do
      Code.ensure_loaded(Kubernetes)
      assert function_exported?(Kubernetes, :apply, 2)
    end

    test "delete/4 is defined" do
      assert function_exported?(Kubernetes, :delete, 4)
    end
  end

  describe "apply/2 — error handling" do
    test "returns error for invalid manifest" do
      result = Kubernetes.apply("/nonexistent/manifest.yaml")
      assert {:error, {:apply_failed, _, _}} = result
    end
  end
end
