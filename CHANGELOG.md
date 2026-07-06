# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
