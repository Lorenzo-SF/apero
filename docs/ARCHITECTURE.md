# Apero — Architectural Reference

> Pure utility library for Elixir — v3.1.0
> No shell execution. Pure Elixir/Erlang.

---

## 1. What is Apero

Apero is the **foundation library** of the Lorenzo-SF ecosystem. It provides
all pure-Elixir and pure-Erlang utilities that the other projects consume:
HTTP client, cryptography, file I/O, environment/config management, OS
detection, retry logic, caching, and process introspection.

**Key rule**: Apero does NOT execute shell commands. If it needs the shell,
it belongs in Trebejo.

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                        Apero (Facade)                         │
│  lib/apero.ex — delegates to all subsystems                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌───────────┐  │
│  │  Cache   │  │   Crypto   │  │   File   │  │   HTTP    │  │
│  │          │  │            │  │          │  │           │  │
│  │ ETS TTL  │  │ AES-256    │  │ atomic   │  │ get/post/ │  │
│  │ lazy exp │  │ SHA256/512 │  │ checksum │  │ stream    │  │
│  │ adapter  │  │ Argon2id   │  │ watcher  │  │ adapter   │  │
│  └──────────┘  └────────────┘  └──────────┘  └───────────┘  │
│                                                              │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌───────────┐  │
│  │   Env    │  │   Conf     │  │   OS     │  │   Retry   │  │
│  │          │  │            │  │          │  │           │  │
│  │ .env R/W │  │ JSON/YAML │  │ type     │  │ exp back  │  │
│  │ get/set  │  │ TOML      │  │ distro   │  │ + jitter  │  │
│  │ casting  │  │ schema    │  │ WSL det  │  │ non-block │  │
│  └──────────┘  └────────────┘  └──────────┘  └───────────┘  │
│                                                              │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐                 │
│  │   Proc   │  │  Packages  │  │ Network  │                 │
│  │          │  │            │  │          │                 │
│  │ which/1  │  │ apt/brew/  │  │ DNS res  │                 │
│  │ os_pid   │  │ pacman..   │  │ (pure)   │                 │
│  └──────────┘  └────────────┘  └──────────┘                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Subsystems

### 3.1 Cache (Apero.Cache)
- **Adapter pattern**: `Apero.Cache.Adapter` behaviour
- **ETS backend**: `Apero.Cache.ETS` — GenServer per named table, TTL with lazy expiry + periodic sweep
- **Crypto cache**: `Apero.Cache.Crypto` — memoizes SHA256/512/MD5 in named ETS, initialized at app startup
- API: `put`, `get`, `fetch`, `delete`, `flush`, `size`, `member?`

### 3.2 Crypto (Apero.Crypto)
- **Cipher**: AES-256-GCM (encrypt/decrypt), ChaCha20-Poly1305, AES-256-CTR streaming
- **Hash**: SHA256, SHA512, MD5, HMAC — all via `:crypto`
- **Key**: PBKDF2, Argon2id, ECDH X25519, RSA 2048-bit
- **Random**: `generate_key`, `random_hex`, `random_token`, `random_password`, `secure_compare`

### 3.3 File (Apero.File)
- **Path**: `dir?`, `file?`, `exists?`, `ensure_dir`, `copy`, `move`, `delete`, `glob`, `write`, `read`
- **IO**: `atomic_write` (temp+rename), `checksum` (stream-based, 64KB chunks), `with_tmp_file/dir`
- **Tree**: ASCII tree generation with UTF-8 box-drawing characters
- **Watcher**: GenServer wrapping `file_system` library, debounced event batching

### 3.4 HTTP (Apero.Http)
- **Adapter pattern**: `Apero.Http.Adapter` behaviour
- **Default adapter**: Finch — `Apero.Http.Adapter.Finch`, lazy-started pool
- **Methods**: GET, POST, PUT, PATCH, DELETE, QUERY (RFC 7231)
- **Request/Response/Error** structs with auto-decoded JSON
- **Streaming**: `Apero.Http.stream/7` for SSE and large responses

### 3.5 Env (Apero.Env)
- `.env` file loading, read/write
- `get`/`set`/`delete` with type casting (`get_as/2`)
- Required key validation (`require_keys/1`)

### 3.6 Conf (Apero.Conf)
- Unified config file interface for JSON, YAML, TOML
- Auto-detects format from extension
- Nested key access (dot-separated), schema validation, config merge

### 3.7 OS (Apero.OS)
- `type/0` → `:linux`, `:macos`, `:windows`
- `hostname`, `distro`, `wsl?`, `container?`
- Pure Erlang (`:os`, `:inet`), no shell

### 3.8 Proc (Apero.Proc)
- `command_exists?/1`, `which/1` — PATH lookup
- `os_pid`, `scheduler_count`, `vm_memory`, `vm_uptime`
- Pure Elixir, no shell

### 3.9 Retry (Apero.Retry)
- **Blocking**: `with/2` — `Process.sleep` with exponential backoff + jitter
- **Non-blocking**: `schedule_next/7 + handle_message/1` — for GenServers
- Configurable: max_attempts, base_delay, max_delay, retry predicate, on_retry callback

### 3.10 Packages (Apero.Packages)
- Package manager detection: apt, brew, pacman, dnf, yum, apk, zypper, winget, choco, nix
- `detect/0`, `preferred/0`, `available?/1`

### 3.11 Network (Apero.Network)
- DNS resolution via `:inet.gethostbyname` — pure Erlang

---

## 4. Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Jason | ~> 1.4 | JSON encoding/decoding |
| file_system | ~> 1.0 | File watching (Apero.File.Watcher) |
| Finch | ~> 0.23 | HTTP client (Apero.Http.Adapter.Finch) |
| yaml_elixir | ~> 2.9 | YAML config parsing (optional) |
| toml | ~> 0.7 | TOML config parsing/encoding (optional) |

**Apero depends on NO other Lorenzo-SF project.** It is the root of the
dependency tree.

---

## 5. Consumed by

| Project | What it uses |
|---------|--------------|
| **Trebejo** | `Apero.OS`, `Apero.Proc`, `Apero.File`, `Apero.Packages` |
| **Candil** | `Apero.Http`, `Apero.Retry`, `Apero.OS`, `Apero.Http.Finch` |
| **Botica** | `Apero.OS` (`Apero.OS.type/0`) |
| **Alaja** | (none directly — uses Pote for colors) |
| **Delfos** | (none directly since v2.8.0 — crypto is inline, HTTP via Candil) |

---

## 6. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **No shell execution** | Separation of concerns: Apero = pure, Trebejo = shell. Prevents security issues and test complexity. |
| **Adapter pattern for HTTP** | Finch is default but swappable. `Apero.Http.Adapter` behaviour allows custom adapters. |
| **Adapter pattern for Cache** | ETS is default but Redis/Memcached adapters can be added without changing API. |
| **Lazy Finch pool** | `ensure_started/0` called before first request — no startup cost for apps that don't use HTTP. |
| **Atomic writes** | `atomic_write` uses temp file + rename — prevents corruption on crash. |
| **`@deprecated` Crypto facade** | `Apero.Crypto` is deprecated in favor of direct submodule use. Backward compatibility maintained. |
| **ET TTL with lazy expiry** | Sweep thread + lazy check on read — balances memory vs CPU. |

---

## 7. Application Startup

```elixir
Apero.Application.start/2
  └── Apero.Cache.Crypto.init_table()   # creates :apero_cache_crypto ETS table
  └── Supervisor.start_link([], ...)    # empty supervisor (extension point)
```

No children started by default. The cache table is created directly via
`:ets.new` (not a GenServer) for zero-overhead reads.

---

## 8. Current State (v3.1.0 — Jul 2026)

- 38 source modules across 11 subsystems
- 16 test files (~80% coverage target)
- 4 crypto tests skipped (`.skip` files)
- Roadmap: `Pote.Converters.Generic` refactor pending, Trebejo migration reviewed
