# Changelog

All notable changes to Apero are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `@doc` strings for every public function in the `Apero` facade
  (`encrypt/2`, `decrypt/2`, `sha256/1`, `sha512/1`, `md5/1`, `get_env/2`,
  `put_env/2`, `os_type/0`, `retry/2`).
- `@doc` for `Apero.Retry.with/2` documenting options and the
  blocking vs non-blocking paths.
- `@doc` for `Apero.File.Watcher.start_link/1` documenting required
  `:dirs` and `:callback` options and `:debounce_ms`.

### Changed
- `Apero.Conf.get/2` and `Apero.Conf.set/3` no longer fall back to
  `String.to_atom/1`. The implementation now uses
  `String.to_existing_atom/1` and preserves string keys when no atom
  exists, removing the atom-table DoS surface from untrusted config
  paths.
- `Apero.Retry.schedule_next/7` and `Apero.Retry.handle_message/1`
  `@spec` were corrected: the `on_retry` callback receives a map
  (`%{attempt: integer, result: any, delay: integer}`), not arity 0.
- `Apero.Http.Adapter.Finch` now uses local aliases for
  `Apero.Http.{Error, Request, Response}` and the `Apero.Http.Finch`
  pool module to satisfy Credo's `AliasUsage` check.
- `Apero.HttpTest` is now `async: false` because the
  `Apero.Http.Finch` named pool is process-global and the
  `request/1 returns {:error, _} on connection refused` test would
  otherwise race with the `Finch lifecycle` test.

### Fixed
- `Apero.Conf.key_to_atom/1` no longer creates atoms dynamically; the
  `String.to_atom` fallback path was removed (P1-1 in
  `docs/AUDIT.md`).
- A Dialyzer `pattern_match_cov` warning in the now-removed
  `key_to_existing_or_string/1` catch-all clause.
- 22 Credo `--strict` warnings (`AliasUsage`, `AliasOrder`, `Nesting`)
  across `lib/apero/http/adapter/finch.ex`,
  `test/apero/http/adapter/finch_test.exs`, and
  `test/apero/http_test.exs`.

### Pipeline
- `mix format` — clean, no diff.
- `mix compile --warnings-as-errors` — exit 0.
- `mix credo --strict --format=json` — 0 issues.
- `mix test --cover` — 172 tests, 0 failures, 48.7% coverage.
- `mix dialyzer` — 0 errors.

## [3.1.0] — 2026-07-19

### Added
- `Apero.Http` — HTTP client facade (`get/post/put/patch/delete/query/request/stream`),
  `Apero.Http.Adapter` behaviour, default `Apero.Http.Adapter.Finch`,
  and `Apero.Http.{Request, Response, Error, Finch, Method.*}` modules.
- `Apero.Retry.schedule_next/7` and `Apero.Retry.handle_message/1`
  GenServer-friendly, non-blocking retry path.
- `Apero.Cache.Crypto` — ETS memoisation wrapper around
  `Apero.Crypto.Hash.{sha256, sha512, md5}/1`.
- `Apero.Conf` — unified JSON / YAML / TOML config loader with
  `load/2`, `parse/2`, `write/3`, `encode/2`, nested `get/2`, `set/3`,
  `validate/2`, `merge/1`, and `print_summary/2`.
- `Apero.Env.require_keys/1` and `Apero.Env.get_as/2` for
  type-coerced env access.
- `mix` aliases: `mix qa` and `mix lint`.

### Changed
- `Apero` is the foundation library of the Lorenzo-SF ecosystem; all
  shell-based modules (`Docker`, `Git`, `SSH`, `Kubernetes`,
  `Compress`, `Network`, `OS` arch/kernel/memory, `Proc`
  ps/kill/lsof, `File.watch`) moved to [Trebejo](https://hex.pm/packages/trebejo)
  v1.0.0.

### Security
- `Apero.OS.wsl?/0` switched from the fragile `PATH` heuristic to
  `/proc/sys/fs/binfmt_misc/WSLInterop` + `/proc/version` checks.

## [3.0.0] — 2025-12-15

### Changed
- Apero v3.0.0 split shell utilities out to Trebejo. Apero is now
  pure Elixir/Erlang with no shell execution.

[Unreleased]: https://github.com/Lorenzo-SF/apero/compare/v3.1.0...HEAD
[3.1.0]: https://github.com/Lorenzo-SF/apero/releases/tag/v3.1.0
[3.0.0]: https://github.com/Lorenzo-SF/apero/releases/tag/v3.0.0
