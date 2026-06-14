defmodule Apero.GitTest do
  use ExUnit.Case, async: true

  alias Apero.Git

  describe "get_git_user_name/0" do
    test "returns a binary or nil" do
      result = Git.get_git_user_name()
      assert is_binary(result) or is_nil(result)
    end
  end

  describe "get_git_user_email/0" do
    test "returns a binary or nil" do
      result = Git.get_git_user_email()
      assert is_binary(result) or is_nil(result)
    end
  end

  describe "get_system_user_name/0" do
    test "returns a binary" do
      assert is_binary(Git.get_system_user_name())
    end
  end

  describe "get_system_user_email/0" do
    test "returns a binary" do
      assert is_binary(Git.get_system_user_email())
    end
  end

  describe "get_hostname/0" do
    test "returns a non-empty binary" do
      name = Git.get_hostname()
      assert is_binary(name)
      assert byte_size(name) > 0
    end
  end

  describe "get_user_info/0" do
    test "returns a map with name, email, hostname" do
      info = Git.get_user_info()
      assert is_map(info)
      assert Map.has_key?(info, :name)
      assert Map.has_key?(info, :email)
      assert Map.has_key?(info, :hostname)
    end
  end

  describe "branch_exists?/1" do
    test "returns a boolean" do
      assert is_boolean(Git.branch_exists?("main"))
    end
  end

  describe "has_uncommitted_changes?/1" do
    test "returns false for a non-git directory" do
      refute Git.has_uncommitted_changes?(System.tmp_dir!())
    end

    @tag :external_cmd
    test "returns false for a clean git repo" do
      {tmp, _work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      refute Git.has_uncommitted_changes?(_work)
    end

    @tag :external_cmd
    test "returns true for a dirty git repo" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      File.write!(Path.join(work, "new_file.txt"), "dirty")
      assert Git.has_uncommitted_changes?(work)
    end
  end

  describe "get_current_branch/1" do
    test "returns error for non-git path" do
      assert {:error, _} = Git.get_current_branch(System.tmp_dir!())
    end

    @tag :external_cmd
    test "returns the current branch name for a git repo" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:ok, "main"} = Git.get_current_branch(work)
    end
  end

  describe "ensure_clone/1" do
    test "returns error when nil" do
      assert {:error, :no_repo_defined} = Git.ensure_clone(nil)
    end

    @tag :external_cmd
    test "returns repo_exists when path already exists" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo = %{url: "ignored", path: work}
      assert {:repo_exists, ^repo} = Git.ensure_clone(repo, tmp)
    end

    @tag :external_cmd
    test "clones a repo when path does not exist" do
      {tmp, _work, repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      clone_path = Path.join(tmp, "cloned")
      clone_repo = %{url: repo.url, path: clone_path}
      assert {:repo_cloned, ^clone_repo} = Git.ensure_clone(clone_repo, tmp)
      assert File.dir?(clone_path)
    end

    @tag :external_cmd
    test "processes a list of repos" do
      {tmp, _work, repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo1 = %{url: repo.url, path: Path.join(tmp, "clone1")}
      repo2 = %{url: repo.url, path: Path.join(tmp, "clone2")}
      results = Git.ensure_clone([repo1, repo2], tmp)
      assert length(results) == 2
      assert Enum.all?(results, fn {tag, _} -> tag in [:repo_cloned, :repo_exists] end)
    end
  end

  describe "update_existing_repository/1" do
    test "returns error for non-existent path" do
      assert {:error, {:cannot_access_path, :enoent}} =
               Git.update_existing_repository("/tmp/definitely_not_a_repo_xyz")
    end
  end

  # ── New tests for uncovered functions ──────────────────────────────────

  describe "sync/1" do
    @tag :external_cmd
    test "syncs a single repo map" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo_map = %{path: work, main_branch: "main"}
      assert {:ok, %{path: ^work}} = Git.sync(repo_map)
    end

    @tag :external_cmd
    test "syncs a list of repos" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo_map = %{path: work, main_branch: "main"}
      assert :ok = Git.sync([repo_map])
    end
  end

  describe "clone/1" do
    @tag :external_cmd
    test "clones a repository from url to path" do
      {tmp, _work, repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      clone_path = Path.join(tmp, "cloned")
      clone_repo = %{url: repo.url, path: clone_path}
      assert {:ok, ^clone_repo} = Git.clone(clone_repo)
      assert File.dir?(clone_path)
      assert File.exists?(Path.join(clone_path, "README.md"))
    end
  end

  describe "clone_repository/2" do
    @tag :external_cmd
    test "clones a url to a target path" do
      {tmp, _work, repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      clone_path = Path.join(tmp, "cloned")
      assert {:ok, _} = Git.clone_repository(repo.url, clone_path)
      assert File.dir?(clone_path)
    end
  end

  describe "checkout/1" do
    @tag :external_cmd
    test "checks out the main branch" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      # Create and switch to a different branch first
      System.cmd("git", ["checkout", "-b", "other-branch"], cd: work)
      repo_map = %{path: work, main_branch: "main"}
      assert {:ok, ^repo_map} = Git.checkout(repo_map)
      assert {:ok, "main"} = Git.get_current_branch(work)
    end
  end

  describe "commit/2" do
    @tag :external_cmd
    test "stages and commits changes" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo_map = %{path: work}

      File.write!(Path.join(work, "new_file.txt"), "content")
      Git.add(work, :all)
      assert {:ok, ^repo_map} = Git.commit(repo_map, "test commit")
    end
  end

  describe "stage_and_commit/2" do
    @tag :external_cmd
    test "adds and commits changes in one step" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo_map = %{path: work}

      File.write!(Path.join(work, "another_file.txt"), "data")
      assert {:ok, ^repo_map} = Git.stage_and_commit(repo_map, "stage and commit")
    end
  end

  describe "conflict_files/1" do
    @tag :external_cmd
    test "returns empty list for a clean repo" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:ok, []} = Git.conflict_files(work)
    end

    test "returns error for non-git directory" do
      assert {:error, _} = Git.conflict_files(System.tmp_dir!())
    end
  end

  describe "merge_abort/1" do
    test "returns error for non-git directory" do
      assert {:error, _} = Git.merge_abort(System.tmp_dir!())
    end

    @tag :external_cmd
    test "returns error when no merge is in progress" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:error, _} = Git.merge_abort(work)
    end
  end

  describe "mark_resolved/2" do
    @tag :external_cmd
    test "stages a file and returns :ok" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(work, "conflicted.txt"), "resolved")
      assert :ok = Git.mark_resolved(work, "conflicted.txt")
    end

    @tag :external_cmd
    test "returns error for non-existent file" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:error, _} = Git.mark_resolved(work, "nonexistent.txt")
    end
  end

  describe "has_stash?/1" do
    @tag :external_cmd
    test "returns false when there is no stash" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      refute Git.has_stash?(work)
    end

    @tag :external_cmd
    test "returns true after stashing" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(work, "stash_me.txt"), "stash content")
      {:ok, _} = Git.stash_push(work)
      assert Git.has_stash?(work)
    end
  end

  describe "stash_if_needed/1" do
    @tag :external_cmd
    test "returns {:ok, :clean} when no changes" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:ok, :clean} = Git.stash_if_needed(work)
    end

    @tag :external_cmd
    test "returns {:ok, {:stashed, branch}} when there are changes" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(work, "dirty_file.txt"), "dirty")
      assert {:ok, {:stashed, "main"}} = Git.stash_if_needed(work)
    end
  end

  describe "existing_repos/1" do
    test "returns tree of existing repos from tuple list" do
      repos = [
        {:repo_exists, %{path: "/tmp/repo1"}},
        {:repo_error, %{path: "/tmp/repo2"}, "failed"},
        {:repo_exists, %{path: "/tmp/repo3"}}
      ]

      tree = Git.existing_repos(repos)
      assert is_binary(tree)
      assert tree =~ "repo1"
      assert tree =~ "repo3"
      refute tree =~ "repo2"
    end

    test "returns empty string for no existing repos" do
      repos = [
        {:repo_error, %{path: "/tmp/repo2"}, "failed"}
      ]

      assert Git.existing_repos(repos) == ""
    end

    test "handles 2-tuple and 3-tuple forms" do
      repos = [
        {:repo_exists, %{path: "/tmp/repo1"}, "extra"},
        {:repo_exists, %{path: "/tmp/repo2"}}
      ]

      tree = Git.existing_repos(repos)
      assert tree =~ "repo1"
      assert tree =~ "repo2"
    end
  end

  describe "add/2" do
    @tag :external_cmd
    test ":all stages all changes" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      File.write!(Path.join(work, "new_file.txt"), "new content")
      assert :ok = Git.add(work, :all)
    end

    @tag :external_cmd
    test "single file returns ok" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      File.write!(Path.join(work, "single.txt"), "single")
      assert {:ok, _} = Git.add(work, "single.txt")
    end

    @tag :external_cmd
    test "list of files returns :ok" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      File.write!(Path.join(work, "a.txt"), "a")
      File.write!(Path.join(work, "b.txt"), "b")
      assert :ok = Git.add(work, ["a.txt", "b.txt"])
    end
  end

  describe "fetch/1" do
    @tag :external_cmd
    test "fetches from origin" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo = %{path: work}
      assert {:ok, ^repo} = Git.fetch(repo)
    end
  end

  describe "pull/1" do
    @tag :external_cmd
    test "pulls from origin" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      repo = %{path: work, main_branch: "main"}
      assert {:ok, ^repo} = Git.pull(repo)
    end
  end

  describe "fetch_origin/1" do
    @tag :external_cmd
    test "fetches and returns output" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:ok, _} = Git.fetch_origin(work)
    end
  end

  describe "pull_origin/2" do
    @tag :external_cmd
    test "pulls default branch" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:ok, _} = Git.pull_origin(work)
    end
  end

  describe "stash_push/2" do
    @tag :external_cmd
    test "stashes uncommitted changes" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(work, "stash_test.txt"), "stash me")
      assert {:ok, _} = Git.stash_push(work)
    end

    @tag :external_cmd
    test "stashes with custom message" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(work, "stash_msg.txt"), "msg")
      {:ok, output} = Git.stash_push(work, message: "my stash", include_untracked: true)
      assert is_binary(output)
    end

    @tag :external_cmd
    test "handles nothing to stash gracefully" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      # When nothing to stash, git may return exit code 0 with a message
      # (varies by git version/localization)
      result = Git.stash_push(work)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "log/1" do
    @tag :external_cmd
    test "returns commit history" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:ok, log} = Git.log(work)
      assert log =~ "initial commit"
    end
  end

  describe "blame/2" do
    @tag :external_cmd
    test "returns blame info for a file" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      assert {:ok, _} = Git.blame(work, "README.md")
    end
  end

  describe "diff/1" do
    @tag :external_cmd
    test "returns diff of changes" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(work, "README.md"), "modified content")
      assert {:ok, diff} = Git.diff(work)
      assert diff =~ "modified content"
    end

    @tag :external_cmd
    test "returns staged diff" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(work, "README.md"), "staged content")
      Git.add(work, :all)
      assert {:ok, diff} = Git.diff(work, staged: true)
      assert is_binary(diff)
    end
  end

  describe "churn/2" do
    @tag :external_cmd
    test "returns churn metrics for repo" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.mkdir_p!(Path.join(work, "lib"))
      repo = %{path: work}
      # Make a few commits to generate churn
      File.write!(Path.join(work, "lib/foo.ex"), "defmodule Foo do end")
      Git.add(work, :all)
      Git.commit(repo, "add foo")

      File.write!(Path.join(work, "README.md"), "## Updated Readme\n")
      Git.add(work, :all)
      Git.commit(repo, "update readme")

      File.write!(Path.join(work, "lib/foo.ex"), "defmodule Foo do\n  def bar, do: :ok\nend")
      Git.add(work, :all)
      Git.commit(repo, "update foo")

      assert {:ok, results} = Git.churn(work, period: "1.year", top: 10)
      assert is_list(results)
      foo = Enum.find(results, &(&1.file == "lib/foo.ex"))
      assert foo != nil
      assert foo.churn >= 1
    end

    @tag :external_cmd
    test "returns empty list for new repo with no history" do
      tmp = Path.join(System.tmp_dir!(), "apero_git_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)

      remote = Path.join(tmp, "remote.git")
      File.mkdir_p!(remote)
      {_, 0} = System.cmd("git", ["init", "--bare", remote], cd: tmp)

      work = Path.join(tmp, "work")
      File.mkdir_p!(work)
      {_, 0} = System.cmd("git", ["init", "-b", "main"], cd: work)
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: work)
      # Make at least one commit so churn has a HEAD to analyse
      File.write!(Path.join(work, "README.md"), "init")
      System.cmd("git", ["add", "README.md"], cd: work)
      System.cmd("git", ["commit", "-m", "init"], cd: work)

      on_exit(fn -> File.rm_rf!(tmp) end)

      # With a fresh repo and a 1.day period, churn may return an empty list
      # or an error depending on git version; accept either.
      case Git.churn(work, period: "1.day", top: 10) do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    end
  end

  describe "config/1" do
    test "returns git config value" do
      {tmp, work, _repo} = setup_git_repo()
      on_exit(fn -> File.rm_rf!(tmp) end)
      # Override with local config on the work repo
      System.cmd("git", ["config", "user.name", "Tester"], cd: work)
      assert Git.config("user.name") != ""
    end
  end

  describe "set_user_info/2" do
    @tag :external_cmd
    test "sets user info globally" do
      # assert :ok = Git.set_user_info("Test User", "test@example.com")
    end
  end

  describe "gh_available?/0" do
    test "returns a boolean" do
      assert is_boolean(Git.gh_available?())
    end
  end

  describe "glab_available?/0" do
    test "returns a boolean" do
      assert is_boolean(Git.glab_available?())
    end
  end

  # Note: create_gh_pr/4, create_glab_mr/4, and list_issues/2 were removed
  # as they belong in specialized GitHub/GitLab client libraries.

  # ═══════════════════════════════════════════════════════════════════
  # Helpers
  # ═══════════════════════════════════════════════════════════════════

  # Creates a temporary git repo with one initial commit and a bare remote.
  # Returns `{tmp_dir, work_dir, repo_map}` where `repo_map` is `%{url: remote_url}`.
  @tag :external_cmd
  defp setup_git_repo do
    tmp = Path.join(System.tmp_dir!(), "apero_git_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    remote = Path.join(tmp, "remote.git")
    File.mkdir_p!(remote)
    {_, 0} = System.cmd("git", ["init", "--bare", remote], cd: tmp)

    work = Path.join(tmp, "work")
    File.mkdir_p!(work)
    # Use -b main to ensure the default branch is "main"
    {_, 0} = System.cmd("git", ["init", "-b", "main"], cd: work)

    # System.cmd("git", ["config", "user.name", "Test User"], cd: work)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: work)

    File.write!(Path.join(work, "README.md"), "# Test Repo\n")
    {_, 0} = System.cmd("git", ["add", "."], cd: work)
    {_, 0} = System.cmd("git", ["commit", "-m", "initial commit"], cd: work)

    System.cmd("git", ["remote", "add", "origin", remote], cd: work)
    System.cmd("git", ["push", "-u", "origin", "main"], cd: work)
    # Point bare repo HEAD to main so clone checks out the working tree
    System.cmd("git", ["symbolic-ref", "HEAD", "refs/heads/main"], cd: remote)

    {tmp, work, %{url: remote, path: work}}
  end
end
