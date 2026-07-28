# Apero — Document Index

> v3.1.0 — Pure utility library for Elixir

| Document | Description |
|----------|-------------|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Complete design reference: subsystems (Cache, Crypto, File, HTTP, Env, Conf, OS, Proc, Retry, Packages, Network), dependencies, key decisions |
| [`AUDIT.md`](./AUDIT.md) | Code quality audit: security, coverage (44.6%), typespecs, P0–P3 findings per module, top 5 fixes |
| [`README.md`](../README.md) | English README — installation, basic usage, API overview |
| [`docs/README.es.md`](./README.es.md) | Spanish README |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history and release notes |
| [`LICENSE.md`](../LICENSE.md) | MIT License |
| [`plan_apero.md`](./plan_apero.md) | Historical implementation plan (cache wrapper, lint alias) |

### Ecosystem context

Apero is the **foundation layer** of the Lorenzo-SF ecosystem. It depends on
no other Lorenzo-SF project. See the [dependency graph](../docs/ARCHITECTURE.md#5-consumed-by).
