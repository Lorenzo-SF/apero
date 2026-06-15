# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Apero.Retry` — exponential backoff with jitter for retrying transient operations.
- `Apero.Network` — ping, DNS resolve, TCP port checking, port scanning.
- `Apero.SSH` — thin SSH/SCP wrapper for remote command execution and file copy.
- `Apero.Kubernetes` — `kubectl` wrapper for pods, apply, delete, available? checks.
- `Apero.Cache.Supervisor` — application-level supervisor for cache adapters.
- Tests for the new modules: `test/apero/retry_test.exs`, `test/apero/network_test.exs`, `test/apero/ssh_test.exs`, `test/apero/kubernetes_test.exs`.
- Dep on `{:arrea, github: "Lorenzo-SF/arrea"}` and `{:alaja, github: "Lorenzo-SF/alaja"}`.
- CHANGELOG.md.

### Changed
- **Apero.VFS deleted** — full duplication of Apero.File. The `Apero.File` namespace is now canonical; `Apero.VFS.*` references were removed from `mix.exs` docs.
- `Apero.Application` now starts `Apero.Cache.Supervisor` (the previous VFS Registry is gone).
- `Apero.Git` and `Apero.Crypto` facades now have `@deprecated` markers on all functions that delegate to the new submodules; tests still use the facades (with warnings).

### Removed
- `Apero.Pkg` module and its tests (had been already removed in a previous phase).
- `lib/apero/vfs.ex` and `lib/apero/vfs/` directory (577 lines of duplication, no users).

## [1.0.0] - 2026-06-10

### Added
- Initial release: file operations, Git, Docker, env, conf, OS, proc, cache, compress.
