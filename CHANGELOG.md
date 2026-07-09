# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-07-09

### Breaking: Apero-Trebejo split

Apero 3.0.0 extracts all shell-dependent modules into a new library
**Trebejo**. Apero becomes a **pure utility library** with no Arrea
dependency.

#### Removed modules (moved to Trebejo v1.0.0)

- `Apero.Docker` → `Trebejo.Docker`
- `Apero.Git` / `Apero.Git.Local` → `Trebejo.Git` / `Trebejo.Git.Local`
- `Apero.SSH` → `Trebejo.SSH`
- `Apero.Kubernetes` → `Trebejo.Kubernetes`
- `Apero.Compress` → `Trebejo.Compress`
- `Apero.Network` → `Trebejo.Network`
- `Apero.OS.arch/0`, `kernel_version/0`, `distro/0`, `info/0`,
  `cpu_count/0`, `total_memory_mb/0`, `root?/0`, `wsl?/0`, `container?/0`
  → `Trebejo.OS`
- `Apero.Proc.ps/1`, `kill/2`, `lsof/1`, `fuser/1`, `logs/2`
  → `Trebejo.Proc`
- `Apero.File.watch/3`, `unwatch/1` → `Trebejo.File`
- `Apero.File.IO.disk_usage/1` → `Trebejo.File.IO`

#### Kept in Apero (pure, no Arrea dependency)

- `Apero.OS.type/0`, `hostname/0` (pure Erlang stdlib)
- `Apero.Proc.command_exists?/1`, `which/1`, `available_commands/1`,
  `locate_commands/1`, `os_pid/0`, `scheduler_count/0`, `vm_memory/0`,
  `vm_uptime/0` (pure stdlib)
- `Apero.File` (path ops, tree, watcher GenServer)
- `Apero.File.IO` (atomic writes, checksums, temp files, locking)
- `Apero.Env`, `Apero.Conf`, `Apero.Retry`, `Apero.Cache`
- `Apero.Crypto` and submodules

#### Dependency changes

- **Removed**: `{:arrea, "~> 2.1.0"}` — Apero no longer depends on Arrea
- **Migration guide**: see `README.md` or `Trebejo` docs for the full
  module mapping

## [2.1.0] - 2026-07-07

### Changed
- **`Apero.OS`** and **`Apero.Network`** migrated to Arrea
  (`APER-100`). All shell commands now route through
  `Arrea.Command.execute/2` so consumers get the full Arrea infra:
  real timeout cancellation, validation, telemetry, sudo allowlist.
- **`Apero.Proc`** migrated to Arrea (`APER-101`). `Process`-related
  helpers (pid info, signal sending) now use Arrea primitives.
- **`Apero.Git`** and **`Apero.Git.Local`** migrated to Arrea
  (`APER-102`). `git` invocations routed through Arrea.
- **`Apero.Docker`** and **`Apero.Kubernetes`** migrated to Arrea
  (`APER-103`). `kubectl` and `docker` calls now use Arrea.
- **`Apero.SSH`** and the rest of **`Apero.Kubernetes`** (final pass)
  migrated to Arrea (`APER-104`). SCP/SSH wrappers and the remaining
  `kubectl` operations unified under `Arrea.Command`.
- **`Apero.Compress`** and **`Apero.File.IO`** migrated to Arrea
  (`APER-105`). Compression (`gzip`/`gunzip`/`tar`) and File.IO
  wrappers go through Arrea for telemetry and validation.

### Fixed
- **`Apero.Docker` / `Apero.Network` / `Apero.Git`** tests were
  host-fragile: Docker volume/network tests assumed `/var/run/docker.sock`
  and Git config tests assumed `$HOME/.gitconfig`. Now they pass on
  any host (CI or local), skipping gracefully when the underlying
  resource is missing.
- **`Apero.Kubernetes.pods/2`**: was returning the legacy
  `{output, exit_code}` 2-tuple while the `@spec` and `@doc` promised
  `{:ok, output} | {:error, reason}`. Dialyzer flagged this as
  `invalid_contract`. The body now wraps the result, so the function
  honours its declared contract.

### Docs
- **README badge** and **`source_ref`** in `mix.exs` aligned to the
  canonical `2.0.0` tag (no `v` prefix).
- **Footer typo** fixed: "Tag v1.0.0" → "Tag 1.0.0".
- **CHANGELOG footer**: drop `v` prefix from tag references to match
  the canonical tag convention.

## [2.0.0] - 2026-07-05

This release consolidates everything between 1.0.0 and the current
HEAD — including the 0.2.0 facade refactor, the 0.2.1 deprecation
fixes, the production hardening, and the Fase 1.2 LLM module
extraction. Earlier `0.x` versions are no longer maintained and have
been collapsed into this single canonical entry.

### Added

- **`Apero.Retry`** — exponential backoff with jitter for retrying
  transient operations. Non-blocking helpers: `schedule_next/7`,
  `handle_message/1`.
- **`Apero.Network`** — ping, DNS resolve, TCP port checking, port
  scanning.
- **`Apero.SSH`** — thin SSH/SCP wrapper for remote command execution
  and file copy. Includes SSH key verification.
- **`Apero.Kubernetes`** — `kubectl` wrapper for pods, apply, delete,
  available? checks.
- **`Apero.Cache.Supervisor`** — application-level supervisor for
  cache adapters.
- **`Apero` top-level facade** — `Apero.os_type/0`, `Apero.os_arch/0`,
  `Apero.encrypt/2`, `Apero.decrypt/2`, `Apero.sha256/1`,
  `Apero.sha512/1`, `Apero.md5/1` with `defdelegate` to canonical
  submodules.
- **`Apero.Llm.Health`**, **`Apero.Llm.ConfigManager`**,
  **`Apero.Llm.Embeddings`** — LLM domain modules (moved to `Candil`
  later in this release cycle).
- **CI pipeline**: multi-stage workflow — format → credo → sobelow →
  test+coverage → dialyzer, plus `workflow_dispatch` trigger for
  manual re-runs.
- Deps on `{:arrea, github: "Lorenzo-SF/arrea"}` and
  `{:alaja, github: "Lorenzo-SF/alaja"}`.
- CHANGELOG.md.

### Fixed

- **Deprecation warnings** in `Apero` top-level facade: redirect
  `encrypt/2`, `decrypt/2` to `Apero.Crypto.Cipher` and `sha256/1`,
  `sha512/1`, `md5/1` to `Apero.Crypto.Hash`.
- **SSH key verification** in production hardening pass.
- **Unbiased random password** generation.
- **Restored Elixir 1.19 requirement** (was downgraded during local
  testing).
- **Corrected pote SHA** in `mix.lock`.
- **`source_ref` placement** — moved inside `docs` array in `mix.exs`.

### Changed

- **i18n**: translated remaining Spanish documentation to English.
  `README_ES.md` moved to `docs/README.es.md` (English-only policy).
- **Apero.VFS deleted** — full duplication of `Apero.File`. The
  `Apero.File` namespace is now canonical; `Apero.VFS.*` references
  removed from `mix.exs` docs.
- **`Apero.Application`** now starts `Apero.Cache.Supervisor` (the
  previous VFS Registry is gone).
- **`Apero.Git` and `Apero.Crypto` facades** — `@deprecated` markers
  on all functions that delegate to submodules.
- **`mix format`** applied across the codebase.
- **README**: version badges bumped to `0.2.0`, docs rewritten to
  English-only enforcement.
- **Deps tracking**: arrea and alaja pinned to `main` on GitHub.

### Removed

- **`Apero.Pkg`** module and its tests (already removed in a previous
  phase).
- **`lib/apero/vfs.ex`** and `lib/apero/vfs/` directory (577 lines of
  duplication, no users).
- **`Apero.Llm.*`** — `Health`, `ConfigManager`, `Embeddings` — moved
  to `Candil` where they belong (LLM domain). Entire
  `lib/apero/llm/` directory removed.

### CI

- Multi-stage CI: format → credo → sobelow → test+coverage → dialyzer.
- `workflow_dispatch` added for manual re-runs.
- Sobelow step dropped (Phoenix-only scanner, false positives on libs).
- `--warnings-as-errors` dropped (legacy type warnings in upstream deps).
- Credo step temporarily commented out during refactor.
- Test job temporarily commented out during Fase 1.2.

### Tests

- Tests covering: Retry, Network, SSH, Kubernetes, facade (os_type,
  os_arch), Cache supervision.

## [1.0.0] - 2026-06-10

### Added
- Initial open source release: file operations, Git, Docker, env,
  conf, OS, proc, cache, compress.

[2.1.0]: https://hex.pm/packages/apero/2.1.0
[1.0.0]: https://hex.pm/packages/apero/1.0.0
[2.0.0]: https://github.com/Lorenzo-SF/apero/releases/tag/2.0.0


> ## A note on history
>
> The git history of this repository was rewritten as part of a
> deliberate cleanup effort. The commits you can read describe the
> codebase as it stands today — they do not preserve the original
> chronology of development.
>
> Anything worth keeping from before the rewrite was carried forward
> as tagged releases with explicit `CHANGELOG.md` entries. Anything
> not preserved is, by the maintainer's choice, no longer part of the
> canonical development line.
>
> Tag `1.0.0` points to the initial open-source cut-over; tag
> `2.0.0` points to the current HEAD and the canonical consolidated
> release. All versioned artifacts on Hex.pm and GitHub Releases
> follow this convention.
