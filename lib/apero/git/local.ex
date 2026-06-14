defmodule Apero.Git.Local do
  @moduledoc """
  Local Git operations — clone, commit, pull, push, branch, stash, merge, etc.

  All user-supplied values (commit messages, branch names, file paths)
  are passed as argument lists — never interpolated into shell strings —
  to prevent shell injection attacks.
  """

  @doc """
  Updates an existing repository by fetching from origin.
  """
  @spec update_existing_repository(binary()) :: {:ok, binary()} | {:error, any()}
  def update_existing_repository(repo_path) do
    if File.dir?(repo_path) do
      fetch_repository_updates(repo_path)
    else
      {:error, {:cannot_access_path, :enoent}}
    end
  end

  defp fetch_repository_updates(repo_path) do
    case run_git(["rev-parse", "--git-dir"], cd: repo_path) do
      {:ok, %{exit_code: 0}} -> fetch_all_changes(repo_path)
      _ -> {:error, :not_a_git_repository}
    end
  end

  defp fetch_all_changes(repo_path) do
    case run_git(["fetch", "--all"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      _ -> {:error, :fetch_failed}
    end
  end

  @doc """
  Returns `true` if the given branch exists locally or remotely.
  """
  @spec branch_exists?(binary()) :: boolean()
  def branch_exists?(branch) do
    local =
      run_git(["show-ref", "--verify", "--quiet", "refs/heads/#{branch}"])

    remote =
      run_git(["ls-remote", "--exit-code", "--heads", "origin", branch])

    match?({:ok, %{exit_code: 0}}, local) or match?({:ok, %{exit_code: 0}}, remote)
  end

  @doc """
  Ensures a repository is cloned. If it already exists, updates it.

  Accepts a single repo map, a list of repo maps, or `nil`.
  """
  @spec ensure_clone(nil) :: {:error, :no_repo_defined}
  @spec ensure_clone([map()], binary()) :: [
          {:repo_exists | :repo_cloned, map()} | {:repo_error, map(), term()}
        ]
  @spec ensure_clone(map(), binary()) ::
          {:repo_exists | :repo_cloned, map()} | {:repo_error, map(), term()}
  def ensure_clone(nil), do: {:error, :no_repo_defined}

  def ensure_clone(repos, workspace_path) when is_list(repos) do
    Enum.map(repos, fn repo -> ensure_clone(repo, workspace_path) end)
  end

  def ensure_clone(%{url: _url, path: path} = repo, _workspace_path)
      when is_binary(path) do
    if File.dir?(path) do
      {:repo_exists, repo}
    else
      case clone(repo) do
        {:ok, repo} -> {:repo_cloned, repo}
        {:error, reason} -> {:repo_error, repo, reason}
      end
    end
  end

  @doc """
  Returns a tree string of existing (already-cloned) repositories.
  """
  @spec existing_repos([tuple()]) :: binary()
  def existing_repos(repos) do
    repos
    |> Enum.filter(fn
      {:repo_exists, _, _} -> true
      {:repo_exists, _} -> true
      _ -> false
    end)
    |> Enum.map(fn
      {_, %{path: path}, _} -> path
      {_, %{path: path}} -> path
    end)
    |> Apero.File.Tree.generate_tree()
  end

  @doc """
  Returns a map with the current Git user information.

  Falls back to system user information if Git is not configured.
  """
  @spec get_user_info() :: map()
  def get_user_info do
    %{
      name: get_git_user_name() || get_system_user_name(),
      email: get_git_user_email() || get_system_user_email(),
      hostname: get_hostname()
    }
  end

  @doc """
  Sets Git user name, email, and URL rewrite rules globally.
  """
  @spec set_user_info(binary(), binary()) :: :ok
  def set_user_info(name, email) do
    run_git(["config", "--global", "user.name", name])
    run_git(["config", "--global", "user.email", email])

    run_git(["config", "--global", "url.git@github.com:.insteadOf", "https://github.com/"])

    run_git(["config", "--global", "url.git@gitlab.com:.insteadOf", "https://gitlab.com/"])

    run_git(["config", "--global", "pull.rebase", "false"])
    :ok
  end

  @doc """
  Stages all changes and creates a commit with the given message.
  """
  @spec stage_and_commit(map(), binary()) :: {:ok, map()} | {:error, any()}
  def stage_and_commit(%{path: path} = repo, message) when is_binary(message) do
    with :ok <- add(path, :all),
         {:ok, repo} <- commit(repo, message) do
      {:ok, repo}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown}
    end
  end

  @doc """
  Synchronises a list of repositories (checkout → fetch → pull).
  """
  @spec sync([map()] | map()) :: :ok | {:ok, map()} | {:error, any()}
  def sync(repos) when is_list(repos) do
    Enum.each(repos, &sync/1)
  end

  def sync(%{path: _path} = repo) do
    with {:ok, repo} <- checkout(repo),
         {:ok, repo} <- fetch(repo),
         {:ok, repo} <- pull(repo) do
      {:ok, repo}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stages files in a repository.

  Pass `:all` to stage everything, a list of paths, or a single path binary.
  """
  @spec add(binary(), :all | [binary()] | binary()) :: :ok | {:ok, binary()} | {:error, any()}
  def add(repo_path, :all) do
    case run_git(["add", "."], cd: repo_path) do
      {:ok, %{exit_code: 0}} -> :ok
      _ -> {:error, :add_failed}
    end
  end

  def add(repo_path, files) when is_list(files) do
    Enum.each(files, fn file -> add(repo_path, file) end)
    :ok
  end

  def add(repo_path, file) when is_binary(file) do
    case run_git(["add", "--", file], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Checks out the `main_branch` of a repository, stashing uncommitted
  changes first if necessary.
  """
  @spec checkout(map()) :: {:ok, map()} | {:error, any()}
  def checkout(%{path: path, main_branch: target_branch} = repo)
      when not is_nil(path) and not is_nil(target_branch) do
    if has_uncommitted_changes?(path) do
      run_git(
        ["stash", "push", "-u", "-m", "apero auto-stash before checkout"],
        cd: path
      )
    end

    case run_git(["checkout", target_branch], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Clones a repository from `url` to `path`.
  """
  @spec clone(map()) :: {:ok, map()} | {:error, any()}
  def clone(%{url: url, path: path} = repo) do
    case clone_repository(url, path) do
      {:ok, _output} -> {:ok, repo}
      {:error, output} -> {:error, {output, repo}}
    end
  end

  @doc """
  Creates a commit with the given message in a repository.
  """
  @spec commit(map(), binary()) :: {:ok, map()} | {:error, any()}
  def commit(%{path: path} = repo, message) do
    case run_git(["commit", "-m", message], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets a Git configuration value (local → global → system).
  """
  @spec config(binary()) :: binary()
  def config(attr) do
    case run_git(["config", "--get", attr]) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output)
      _ -> ""
    end
  end

  @doc """
  Gets a Git configuration value from the global scope.
  """
  @spec config_global(binary()) :: binary()
  def config_global(attr) do
    case run_git(["config", "--global", "--get", attr]) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output)
      _ -> ""
    end
  end

  @doc """
  Gets a Git configuration value from the local (repo) scope.
  """
  @spec config_local(binary()) :: binary()
  def config_local(attr) do
    case run_git(["config", "--local", "--get", attr]) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output)
      _ -> ""
    end
  end

  @doc """
  Fetches all remotes in a repository.
  """
  @spec fetch(map()) :: {:ok, map()} | {:error, any()}
  def fetch(%{path: path} = repo) do
    case run_git(["fetch", "--all"], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the configured Git user name, or `nil` if not set.
  """
  @spec get_git_user_name() :: binary() | nil
  def get_git_user_name do
    case run_git(["config", "user.name"]) do
      {:ok, %{exit_code: 0, stdout: output}} ->
        trimmed = String.trim(output)

        if trimmed == "",
          do: nil,
          else: trimmed |> String.split() |> Enum.map_join(" ", &String.capitalize/1)

      _ ->
        nil
    end
  end

  @doc """
  Returns the configured Git user email, or `nil` if not set.
  """
  @spec get_git_user_email() :: binary() | nil
  def get_git_user_email do
    case run_git(["config", "user.email"]) do
      {:ok, %{exit_code: 0, stdout: output}} ->
        trimmed = String.trim(output)
        if trimmed == "", do: nil, else: trimmed

      _ ->
        nil
    end
  end

  @doc """
  Returns the current system user name.
  """
  @spec get_system_user_name() :: binary()
  def get_system_user_name do
    case :os.type() do
      {:unix, _} ->
        (System.get_env("USER") || System.get_env("LOGNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)

      {:win32, _} ->
        (System.get_env("USERNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)
    end
  end

  @doc """
  Returns the current system user email from the `USER_EMAIL` env variable,
  falling back to `"user@domain.com"`.
  """
  @spec get_system_user_email() :: binary()
  def get_system_user_email do
    System.get_env("USER_EMAIL") || "user@domain.com"
  end

  @doc """
  Returns the machine's hostname.
  """
  @dialyzer {:nowarn_function, get_hostname: 0}
  @spec get_hostname() :: binary()
  def get_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "localhost"
    end
  end

  @doc """
  Pulls from origin using the repository's `main_branch`.
  """
  @spec pull(map()) :: {:ok, map()} | {:error, any()}
  def pull(%{path: path, main_branch: branch} = repo) do
    case run_git(["pull", "origin", branch], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches from `origin` in the given repository path.
  """
  @spec fetch_origin(binary()) :: {:ok, binary()} | {:error, binary()}
  def fetch_origin(repo_path) do
    case run_git(["fetch", "origin"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Pulls from `origin` for the given branch (default: `"main"`).
  """
  @spec pull_origin(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  def pull_origin(repo_path, branch \\ "main") do
    case run_git(["pull", "origin", branch], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Clones a repository from `url` to `target_path`.
  """
  @spec clone_repository(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def clone_repository(url, target_path) do
    system_opts = [stderr_to_stdout: true, env: [{"GIT_TERMINAL_PROMPT", "0"}]]

    case run_system_cmd(
           "git",
           ["clone", "--quiet", url, target_path],
           "git clone --quiet <url> <target_path>",
           system_opts
         ) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Returns `true` if there are uncommitted changes in the repository.
  """
  @spec has_uncommitted_changes?(binary()) :: boolean()
  def has_uncommitted_changes?(repo_path) do
    case run_git(["status", "--porcelain"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output) != ""
      _ -> false
    end
  end

  @doc """
  Returns the currently checked-out branch name.
  """
  @spec get_current_branch(binary()) :: {:ok, binary()} | {:error, binary()}
  def get_current_branch(repo_path) do
    case run_git(["rev-parse", "--abbrev-ref", "HEAD"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Pushes stash entries in a repository.

  ## Options

    * `:message` — stash description (default: `"auto-stash"`)
    * `:include_untracked` — include untracked files (default: `true`)

  """
  @spec stash_push(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def stash_push(repo_path, opts \\ []) do
    message = Keyword.get(opts, :message, "auto-stash")
    include_untracked = Keyword.get(opts, :include_untracked, true)

    git_args =
      if include_untracked,
        do: ["stash", "push", "-u", "-m", message],
        else: ["stash", "push", "-m", message]

    case run_git(git_args, cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Returns `true` if the repository has stash entries.
  """
  @spec has_stash?(binary()) :: boolean()
  def has_stash?(repo_path) do
    case run_git(["stash", "list"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output) != ""
      _ -> false
    end
  end

  @doc """
  Stashes uncommitted changes if the working tree is dirty.

  Returns `{:ok, {:stashed, branch}}`, `{:ok, :clean}`, or `{:error, reason}`.
  """
  @spec stash_if_needed(binary()) ::
          {:ok, {:stashed, binary()} | :clean} | {:error, any()}
  def stash_if_needed(repo_path) do
    with {:ok, branch} <- get_current_branch(repo_path) do
      if has_uncommitted_changes?(repo_path) do
        do_stash(repo_path, branch)
      else
        {:ok, :clean}
      end
    end
  end

  defp do_stash(repo_path, branch) do
    case stash_push(repo_path, message: "sync-stash from #{branch}") do
      {:ok, _} -> {:ok, {:stashed, branch}}
      {:error, reason} -> {:error, reason}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Merge conflict handling
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Lists files with merge conflicts in the repo."
  @spec conflict_files(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def conflict_files(repo_path \\ ".") do
    case run_git(["diff", "--name-only", "--diff-filter=U"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} ->
        {:ok, out |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))}

      {:ok, %{stdout: err}} ->
        {:error, String.trim(err)}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc "Aborts a merge in progress."
  @spec merge_abort(binary()) :: {:ok, binary()} | {:error, binary()}
  def merge_abort(repo_path \\ ".") do
    case run_git(["merge", "--abort"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc "Marks a conflicted file as resolved (after manual fix)."
  @spec mark_resolved(binary(), binary()) :: :ok | {:error, binary()}
  def mark_resolved(repo_path, file) do
    case run_git(["add", file], cd: repo_path) do
      {:ok, %{exit_code: 0}} -> :ok
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # History
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Shows commit history (log)."
  @spec log(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def log(repo_path \\ ".", opts \\ []) do
    count = Keyword.get(opts, :count, 10)
    format = Keyword.get(opts, :format, "--oneline")
    format_args = String.split(format, " ")

    case run_git(["log", "-#{count}"] ++ format_args, cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc "Shows who last modified each line of a file (blame)."
  @spec blame(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  def blame(repo_path, file) do
    case run_git(["blame", file], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc "Shows diff of changes."
  @spec diff(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def diff(repo_path \\ ".", opts \\ []) do
    staged = Keyword.get(opts, :staged, false)
    args = if staged, do: ["diff", "--staged"], else: ["diff"]

    case run_git(args, cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Returns churn metrics — the most frequently changed files.

  Runs `git log --name-only` for the given period and counts how many times
  each file has been modified. Results are sorted by churn count descending.

  ## Options
    - `:period` — Time period for git log (default: `"6.months"`)
    - `:top` — Return only the top N files (default: 20)
    - `:branch` — Git branch to analyze (default: current branch)

  ## Examples

      iex> Apero.Git.Local.churn(".")
      {:ok, [%{file: "lib/foo.ex", churn: 15}, ...]}

  """
  @spec churn(binary(), keyword()) :: {:ok, [map()]} | {:error, binary()}
  def churn(repo_path \\ ".", opts \\ []) do
    period = Keyword.get(opts, :period, "6.months")
    top = Keyword.get(opts, :top, 20)
    branch = Keyword.get(opts, :branch, nil)

    args =
      ["log", "--name-only", "--pretty=format:", "--since=#{period}"] ++
        if(branch, do: [branch], else: [])

    case run_git(args, cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} ->
        files =
          out
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.frequencies()
          |> Enum.sort_by(fn {_file, count} -> -count end)
          |> Enum.take(top)
          |> Enum.map(fn {file, count} -> %{file: file, churn: count} end)

        {:ok, files}

      {:ok, %{exit_code: 128, stdout: err}} ->
        if String.contains?(err, "no commits") or String.contains?(err, "no tiene ningún commit") do
          {:ok, []}
        else
          {:error, String.trim(err)}
        end

      {:ok, %{stdout: err}} ->
        {:error, String.trim(err)}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Credential management
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Configures Git credentials (SSH key path or credential helper)."
  @spec setup_credentials(keyword()) :: :ok | {:error, binary()}
  def setup_credentials(opts \\ []) do
    ssh_key = Keyword.get(opts, :ssh_key)
    credential_helper = Keyword.get(opts, :credential_helper, "cache")

    if ssh_key do
      setup_ssh_key(ssh_key)
    else
      setup_credential_helper(credential_helper)
    end
  end

  defp setup_ssh_key(ssh_key) do
    if File.exists?(ssh_key) do
      safe_ssh_cmd = "ssh -i #{ssh_key}"

      case run_git(["config", "--global", "core.sshCommand", safe_ssh_cmd]) do
        {:ok, %{exit_code: 0}} -> :ok
        {:ok, %{stdout: err}} -> {:error, String.trim(err)}
        {:error, reason} -> {:error, inspect(reason)}
      end
    else
      {:error, "SSH key not found: #{ssh_key}"}
    end
  end

  defp setup_credential_helper(credential_helper) do
    case run_git(["config", "--global", "credential.helper", credential_helper]) do
      {:ok, %{exit_code: 0}} -> :ok
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Private helpers
  # ═══════════════════════════════════════════════════════════════════════

  # ────────────────────────────────────────────────────────────────────
  # System command execution (safe, no shell interpolation)
  # ────────────────────────────────────────────────────────────────────

  defp run_git(git_args, opts \\ []) do
    cd = Keyword.get(opts, :cd)
    system_opts = if cd, do: [stderr_to_stdout: true, cd: cd], else: [stderr_to_stdout: true]
    cmd_line = "git " <> Enum.join(git_args, " ")
    run_system_cmd("git", git_args, cmd_line, system_opts)
  end

  defp run_system_cmd(cmd, args, telemetry_cmd_line, opts) do
    start = System.monotonic_time()

    :telemetry.execute([:apero, :git, :command, :start], %{}, %{
      args: telemetry_cmd_line
    })

    result =
      try do
        {out, exit_code} = System.cmd(cmd, args, opts)
        {:ok, %{stdout: out, exit_code: exit_code}}
      rescue
        e -> {:error, inspect(e)}
      end

    duration = System.monotonic_time() - start

    case result do
      {:ok, _} ->
        :telemetry.execute([:apero, :git, :command, :stop], %{duration: duration}, %{
          args: telemetry_cmd_line
        })

      {:error, reason} ->
        :telemetry.execute([:apero, :git, :command, :error], %{duration: duration}, %{
          args: telemetry_cmd_line,
          reason: inspect(reason)
        })
    end

    result
  end

  # ═══════════════════════════════════════════════════════════════════════
  # CLI availability checks
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Checks if the GitHub CLI (gh) is available."
  @spec gh_available?() :: boolean()
  def gh_available?, do: System.find_executable("gh") != nil

  @doc "Checks if the GitLab CLI (glab) is available."
  @spec glab_available?() :: boolean()
  def glab_available?, do: System.find_executable("glab") != nil
end
