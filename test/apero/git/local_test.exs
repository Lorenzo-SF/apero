defmodule Apero.Git.LocalTest do
  use ExUnit.Case, async: true

  alias Apero.Git.Local

  describe "get_git_user_name/0" do
    test "returns a binary or nil" do
      result = Local.get_git_user_name()
      assert is_binary(result) or is_nil(result)
    end
  end

  describe "get_git_user_email/0" do
    test "returns a binary or nil" do
      result = Local.get_git_user_email()
      assert is_binary(result) or is_nil(result)
    end
  end

  describe "get_system_user_name/0" do
    test "returns a binary" do
      assert is_binary(Local.get_system_user_name())
    end
  end

  describe "get_system_user_email/0" do
    test "returns a binary" do
      assert is_binary(Local.get_system_user_email())
    end
  end

  describe "get_hostname/0" do
    test "returns a non-empty binary" do
      name = Local.get_hostname()
      assert is_binary(name)
      assert byte_size(name) > 0
    end
  end

  describe "get_user_info/0" do
    test "returns a map with name, email, hostname" do
      info = Local.get_user_info()
      assert is_map(info)
      assert Map.has_key?(info, :name)
      assert Map.has_key?(info, :email)
      assert Map.has_key?(info, :hostname)
    end
  end

  describe "branch_exists?/1" do
    test "returns a boolean" do
      assert is_boolean(Local.branch_exists?("main"))
    end
  end

  describe "has_uncommitted_changes?/1" do
    test "returns false for a non-git directory" do
      refute Local.has_uncommitted_changes?(System.tmp_dir!())
    end
  end

  describe "get_current_branch/1" do
    test "returns error for non-git path" do
      assert {:error, _} = Local.get_current_branch(System.tmp_dir!())
    end
  end

  describe "ensure_clone/1" do
    test "returns error when nil" do
      assert {:error, :no_repo_defined} = Local.ensure_clone(nil)
    end
  end

  describe "update_existing_repository/1" do
    test "returns error for non-existent path" do
      assert {:error, {:cannot_access_path, :enoent}} =
               Local.update_existing_repository("/tmp/definitely_not_a_repo_xyz")
    end
  end

  describe "conflict_files/1" do
    test "returns error for non-git directory" do
      assert {:error, _} = Local.conflict_files(System.tmp_dir!())
    end
  end

  describe "merge_abort/1" do
    test "returns error for non-git directory" do
      assert {:error, _} = Local.merge_abort(System.tmp_dir!())
    end
  end

  describe "existing_repos/1" do
    test "returns tree of existing repos from tuple list" do
      repos = [
        {:repo_exists, %{path: "/tmp/repo1"}},
        {:repo_error, %{path: "/tmp/repo2"}, "failed"},
        {:repo_exists, %{path: "/tmp/repo3"}}
      ]

      tree = Local.existing_repos(repos)
      assert is_binary(tree)
      assert tree =~ "repo1"
      assert tree =~ "repo3"
      refute tree =~ "repo2"
    end

    test "returns empty string for no existing repos" do
      repos = [{:repo_error, %{path: "/tmp/repo2"}, "failed"}]
      assert Local.existing_repos(repos) == ""
    end
  end

  describe "config/1" do
    test "returns git config value" do
      # Just check it returns a binary (empty or not)
      assert is_binary(Local.config("user.name"))
    end
  end

  describe "config_global/1" do
    test "returns git config global value" do
      assert is_binary(Local.config_global("user.name"))
    end
  end

  describe "config_local/1" do
    test "returns git config local value" do
      assert is_binary(Local.config_local("user.name"))
    end
  end

  describe "gh_available?/0" do
    test "returns a boolean" do
      assert is_boolean(Local.gh_available?())
    end
  end

  describe "glab_available?/0" do
    test "returns a boolean" do
      assert is_boolean(Local.glab_available?())
    end
  end
end
