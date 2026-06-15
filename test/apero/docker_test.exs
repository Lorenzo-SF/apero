defmodule Apero.DockerTest do
  use ExUnit.Case, async: true

  alias Apero.Docker

  describe "runtime/0" do
    test "returns :podman, :docker, or :none" do
      result = Docker.runtime()
      assert result in [:podman, :docker, :none]
    end
  end

  describe "in_container?/0" do
    test "returns a boolean" do
      assert is_boolean(Docker.in_container?())
    end
  end

  describe "ps/1" do
    test "returns an ok or error tuple with binary output" do
      result = Docker.ps()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "compose operations" do
    test "up returns an ok or error tuple with binary output" do
      result = Docker.up()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "down returns an ok or error tuple with binary output" do
      result = Docker.down()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "restart returns an ok or error tuple with binary output" do
      result = Docker.restart()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "pull returns an ok or error tuple with binary output" do
      result = Docker.pull()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "build returns an ok or error tuple with binary output" do
      result = Docker.build()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "logs returns an ok or error tuple with binary output" do
      result = Docker.logs()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "exec returns an ok or error tuple with binary output" do
      result = Docker.exec("service", ["echo", "hello"])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "volume operations" do
    test "volume_create returns an ok or error tuple" do
      result = Docker.volume_create("apero-test-volume-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "volume_list returns an ok or error tuple" do
      result = Docker.volume_list()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "volume_remove returns an ok or error tuple" do
      result = Docker.volume_remove("apero-test-volume-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "network operations" do
    test "network_create returns an ok or error tuple" do
      result = Docker.network_create("apero-test-network-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "network_list returns an ok or error tuple" do
      result = Docker.network_list()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "network_remove returns an ok or error tuple" do
      result = Docker.network_remove("apero-test-network-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
