# Changelog

All notable changes to Apero are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] — 2026-09-18

### Added
- `Apero.RateLimit` — token bucket and leaky bucket rate limiting.
  Named buckets backed by a GenServer (registered via
  `Apero.RateLimit.Registry`) with state mirrored to a public ETS table
  (`:apero_rate_limit`, `read_concurrency: true`). API: `new/1`,
  `allow?/2`, `check/2` (typed `{:error, :rate_limited}`), `wait/3`
  (polls every 10ms, never blocks the BEAM).
- `Apero.Backoff` — exponential backoff with full and decorrelated
  jitter. `delay/2` is pure and testable with a seeded `:rand`;
  `sleep/2` applies the delay. Replaces the 5 custom retry-delay
  implementations spread across candil/delfos/trebejo.
- `Apero.Clock` — injectable clock: `now/0`, `monotonic_ms/0`,
  `with_fixed/2` (scoped override, restores even on raise),
  `set_fixed!/1` (global override for tests, `nil` restores real clock).
  `monotonic_ms/0` is immune to the override so rate limiters stay
  correct under fixed time.
- `Apero.Atomic.File` — atomic writes (temp file + rename in the same
  directory), optional `fsync`, retry on `:eagain`, and `replace/3`
  that leaves the original untouched when the transform errors.
- `Apero.Jsonl` — append-only JSON Lines reader/writer: `write!/3`,
  `append!/3`, `stream!/1`, `read_all/1`, `recover/2`. Corrupted and
  truncated final lines are skipped (with `Logger.warning`) so a crashed
  writer does not corrupt subsequent reads.
- `@doc` strings for every public function in the `Apero` facade
  (`encrypt/2`, `decrypt/2`, `sha256/1`, `sha512/1`, `md5/1`, `get_env/2`,
  `put_env/2`, `os_type/0`, `retry/2`).
- `@doc` for `Apero.Retry.with/2` documenting options and the
  blocking vs non-blocking paths.
- `@doc` for `Apero.File.Watcher.start_link/1` documenting required
  `:dirs` and `:callback` options and `:debounce_ms`.

### Changed
- `Apero.Application` now starts `Apero.RateLimit.Registry` (unique
  keys) and `Apero.RateLimit.Supervisor` (dynamic supervisor) for named
  rate-limit buckets.
- Reactivated crypto test files (`hash_test.exs`, `random_test.exs`,
  previously `.skip`) and added property tests with `stream_data`
  (hash collisions/determinism, `secure_compare` length mismatch).
- CI: `mix format --check-formatted` added to the lint job; `mix lint`
  alias now checks formatting instead of rewriting in place.
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
- `mix credo --strict` — 0 issues.
- `mix test` — 245 tests, 8 properties, 0 failures.
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

[4.0.0]: https://hex.pm/packages/apero/4.0.0
[3.1.0]: https://hex.pm/packages/apero/3.1.0
[3.0.0]: https://hex.pm/packages/apero/3.0.0
[Unreleased]: https://github.com/Lorenzo-SF/apero/compare/4.0.0...HEAD
