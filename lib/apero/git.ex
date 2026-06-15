defmodule Apero.Git do
  @moduledoc """
  Git utilities for repository management, configuration and synchronisation.

  ## Submodules

  This module is a facade that delegates to `Apero.Git.Local` for local operations.

  ## Remote APIs (REMOVED)

  The following functions have been removed from this module as they belong
  in specialized GitHub/GitLab clients:

    * `create_gh_pr/4` — Use a dedicated GitHub client library instead
    * `create_glab_mr/4` — Use a dedicated GitLab client library instead
    * `list_issues/2` — Use a dedicated GitHub client library instead

  ## Security

  All user-supplied values (commit messages, branch names, file paths)
  are passed as argument lists — never interpolated into shell strings —
  to prevent shell injection attacks.
  """

  # ═══════════════════════════════════════════════════════════════════════
  # Aliases to Apero.Git.Local for backward compatibility
  # ═══════════════════════════════════════════════════════════════════════

  alias Apero.Git.Local

  @deprecated "Use Apero.Git.Local.update_existing_repository/1 instead"
  @doc "See `Apero.Git.Local.update_existing_repository/1`."
  @spec update_existing_repository(binary()) :: {:ok, binary()} | {:error, any()}
  defdelegate update_existing_repository(repo_path),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.branch_exists?/1 instead"
  @doc "See `Apero.Git.Local.branch_exists?/1`."
  @spec branch_exists?(binary()) :: boolean()
  defdelegate branch_exists?(branch),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.ensure_clone/2 instead"
  @doc "See `Apero.Git.Local.ensure_clone/2`."
  @spec ensure_clone(nil) :: {:error, :no_repo_defined}
  @spec ensure_clone([map()], binary()) :: [
          {:repo_exists | :repo_cloned, map()} | {:repo_error, map(), term()}
        ]
  @spec ensure_clone(map(), binary()) ::
          {:repo_exists | :repo_cloned, map()} | {:repo_error, map(), term()}
  def ensure_clone(nil), do: Local.ensure_clone(nil)

  def ensure_clone(repos, workspace_path),
    do: Local.ensure_clone(repos, workspace_path)

  @deprecated "Use Apero.Git.Local.existing_repos/1 instead"
  @doc "See `Apero.Git.Local.existing_repos/1`."
  @spec existing_repos([tuple()]) :: binary()
  defdelegate existing_repos(repos),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.get_user_info/0 instead"
  @doc "See `Apero.Git.Local.get_user_info/0`."
  @spec get_user_info() :: map()
  defdelegate get_user_info(),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.set_user_info/2 instead"
  @doc "See `Apero.Git.Local.set_user_info/2`."
  @spec set_user_info(binary(), binary()) :: :ok
  defdelegate set_user_info(name, email),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.stage_and_commit/2 instead"
  @doc "See `Apero.Git.Local.stage_and_commit/2`."
  @spec stage_and_commit(map(), binary()) :: {:ok, map()} | {:error, any()}
  defdelegate stage_and_commit(repo, message),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.sync/1 instead"
  @doc "See `Apero.Git.Local.sync/1`."
  @spec sync([map()] | map()) :: :ok | {:ok, map()} | {:error, any()}
  defdelegate sync(repos),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.add/2 instead"
  @doc "See `Apero.Git.Local.add/2`."
  @spec add(binary(), :all | [binary()] | binary()) :: :ok | {:ok, binary()} | {:error, any()}
  defdelegate add(repo_path, files),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.checkout/1 instead"
  @doc "See `Apero.Git.Local.checkout/1`."
  @spec checkout(map()) :: {:ok, map()} | {:error, any()}
  defdelegate checkout(repo),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.clone/1 instead"
  @doc "See `Apero.Git.Local.clone/1`."
  @spec clone(map()) :: {:ok, map()} | {:error, any()}
  defdelegate clone(repo),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.commit/2 instead"
  @doc "See `Apero.Git.Local.commit/2`."
  @spec commit(map(), binary()) :: {:ok, map()} | {:error, any()}
  defdelegate commit(repo, message),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.config/1 instead"
  @doc "See `Apero.Git.Local.config/1`."
  @spec config(binary()) :: binary()
  defdelegate config(attr),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.config_global/1 instead"
  @doc "See `Apero.Git.Local.config_global/1`."
  @spec config_global(binary()) :: binary()
  defdelegate config_global(attr),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.config_local/1 instead"
  @doc "See `Apero.Git.Local.config_local/1`."
  @spec config_local(binary()) :: binary()
  defdelegate config_local(attr),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.fetch/1 instead"
  @doc "See `Apero.Git.Local.fetch/1`."
  @spec fetch(map()) :: {:ok, map()} | {:error, any()}
  defdelegate fetch(repo),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.get_git_user_name/0 instead"
  @doc "See `Apero.Git.Local.get_git_user_name/0`."
  @spec get_git_user_name() :: binary() | nil
  defdelegate get_git_user_name(),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.get_git_user_email/0 instead"
  @doc "See `Apero.Git.Local.get_git_user_email/0`."
  @spec get_git_user_email() :: binary() | nil
  defdelegate get_git_user_email(),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.get_system_user_name/0 instead"
  @doc "See `Apero.Git.Local.get_system_user_name/0`."
  @spec get_system_user_name() :: binary()
  defdelegate get_system_user_name(),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.get_system_user_email/0 instead"
  @doc "See `Apero.Git.Local.get_system_user_email/0`."
  @spec get_system_user_email() :: binary()
  defdelegate get_system_user_email(),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.get_hostname/0 instead"
  @doc "See `Apero.Git.Local.get_hostname/0`."
  @spec get_hostname() :: binary()
  defdelegate get_hostname(),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.pull/1 instead"
  @doc "See `Apero.Git.Local.pull/1`."
  @spec pull(map()) :: {:ok, map()} | {:error, any()}
  defdelegate pull(repo),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.fetch_origin/1 instead"
  @doc "See `Apero.Git.Local.fetch_origin/1`."
  @spec fetch_origin(binary()) :: {:ok, binary()} | {:error, binary()}
  defdelegate fetch_origin(repo_path),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.pull_origin/2 instead"
  @doc "See `Apero.Git.Local.pull_origin/2`."
  @spec pull_origin(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  defdelegate pull_origin(repo_path, branch \\ "main"),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.clone_repository/2 instead"
  @doc "See `Apero.Git.Local.clone_repository/2`."
  @spec clone_repository(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  defdelegate clone_repository(url, target_path),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.has_uncommitted_changes?/1 instead"
  @doc "See `Apero.Git.Local.has_uncommitted_changes?/1`."
  @spec has_uncommitted_changes?(binary()) :: boolean()
  defdelegate has_uncommitted_changes?(repo_path),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.get_current_branch/1 instead"
  @doc "See `Apero.Git.Local.get_current_branch/1`."
  @spec get_current_branch(binary()) :: {:ok, binary()} | {:error, binary()}
  defdelegate get_current_branch(repo_path),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.stash_push/2 instead"
  @doc "See `Apero.Git.Local.stash_push/2`."
  @spec stash_push(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  defdelegate stash_push(repo_path, opts \\ []),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.has_stash?/1 instead"
  @doc "See `Apero.Git.Local.has_stash?/1`."
  @spec has_stash?(binary()) :: boolean()
  defdelegate has_stash?(repo_path),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.stash_if_needed/1 instead"
  @doc "See `Apero.Git.Local.stash_if_needed/1`."
  @spec stash_if_needed(binary()) ::
          {:ok, {:stashed, binary()} | :clean} | {:error, any()}
  defdelegate stash_if_needed(repo_path),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.conflict_files/1 instead"
  @doc "See `Apero.Git.Local.conflict_files/1`."
  @spec conflict_files(binary()) :: {:ok, [binary()]} | {:error, binary()}
  defdelegate conflict_files(repo_path \\ "."),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.merge_abort/1 instead"
  @doc "See `Apero.Git.Local.merge_abort/1`."
  @spec merge_abort(binary()) :: {:ok, binary()} | {:error, binary()}
  defdelegate merge_abort(repo_path \\ "."),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.mark_resolved/2 instead"
  @doc "See `Apero.Git.Local.mark_resolved/2`."
  @spec mark_resolved(binary(), binary()) :: :ok | {:error, binary()}
  defdelegate mark_resolved(repo_path, file),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.log/2 instead"
  @doc "See `Apero.Git.Local.log/2`."
  @spec log(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  defdelegate log(repo_path \\ ".", opts \\ []),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.blame/2 instead"
  @doc "See `Apero.Git.Local.blame/2`."
  @spec blame(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  defdelegate blame(repo_path, file),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.diff/2 instead"
  @doc "See `Apero.Git.Local.diff/2`."
  @spec diff(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  defdelegate diff(repo_path \\ ".", opts \\ []),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.churn/2 instead"
  @doc "See `Apero.Git.Local.churn/2`."
  @spec churn(binary(), keyword()) :: {:ok, [map()]} | {:error, binary()}
  defdelegate churn(repo_path \\ ".", opts \\ []),
    to: Apero.Git.Local

  @deprecated "Use Apero.Git.Local.setup_credentials/1 instead"
  @doc "See `Apero.Git.Local.setup_credentials/1`."
  @spec setup_credentials(keyword()) :: :ok | {:error, binary()}
  defdelegate setup_credentials(opts \\ []),
    to: Apero.Git.Local

  # ═══════════════════════════════════════════════════════════════════════
  # CLI availability checks (still relevant for local Git operations)
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Checks if the GitHub CLI (gh) is available."
  @spec gh_available?() :: boolean()
  def gh_available?, do: System.find_executable("gh") != nil

  @doc "Checks if the GitLab CLI (glab) is available."
  @spec glab_available?() :: boolean()
  def glab_available?, do: System.find_executable("glab") != nil
end
