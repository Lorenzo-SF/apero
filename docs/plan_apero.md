# Plan for `@apero` (Pure Utility Library)

> **Goal** – Ensure `@apero` meets the highest quality standards: fully documented, fully tested, clean code, and no compilation or style warnings.  Additionally, establish a cache wrapper for expensive cryptographic functions (`sha256/1`, `sha512/1`, `md5/1`) and a dedicated `lint` mix alias.

---

## 1. Preparation

| Step | Action | Outcome |
|------|--------|---------|
| 1.1 | Switch to branch `fix-tools-domains` | Working branch ready |
| 1.2 | Ensure the working tree is clean (commit or stash any in‑progress changes before starting) | Clean working tree |
| 1.3 | `mix deps.get` & `mix deps.compile` | Dependencies up to date |
| 1.4 | Verify dependency overrides have been added for `apero` in all peers
| 1.5 | Commit any pending changes in `pote`, `alaja`, etc., **before** starting modifications.

## 2. Implementation

| Target | Task | Rationale | Notes |
|--------|------|-----------|-------|
| **Cache Module** | Create `lib/apero/cache/crypto.ex` that memoises `sha256/1`, `sha512/1`, `md5/1` | Reduce repeated hashing overhead | Uses ETS, lazy init |
| **Modifications** | Update `Apero.Crypto` to delegate to `Apero.Cache.Crypto` | Unify entry point | Keep backward‑compatibility alias
| **Mix Alias** | Add `lint` alias to `mix.exs` | Quick lint/format/compile/test flow | Uses `credo --strict --format=json`

## 3. Tests

| Test File | Coverage Goal | Key Assertions |
|-----------|---------------|----------------|
| `test/apero/cache/crypto_test.exs` | 100 % on `Apero.Cache.Crypto` | • Same result on repeated call
| | | • ETS has cached entry |

Run `mix test --cover` to confirm all modules covered.

## 4. Documentation

* Update `README.md` with new `Apero.Cache.Crypto` module description.
* Add entry in `CHANGELOG.md` indicating **cache wrapper added**.
* Optionally update docs pages (`docs/README.es.md`).

## 5. Quality

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict --format=json
mix test --cover
mix dialyzer
```
Ensure no warnings or errors.

## 6. Commit & Push

```bash
git add -A
git commit -m "Implement crypto cache wrapper and lint alias for apero"
git push origin fix-tools-domains
```

---

**End of plan for `@apero`**