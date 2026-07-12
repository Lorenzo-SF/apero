# Apero

[![version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/Lorenzo-SF/Apero)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.md)

**Pure utility library for Elixir** — no shell execution. Provides file operations,
cryptography, environment/config handling, retry, cache, and pure OS/Proc introspection.

> Shell-based operations (Docker, Git, SSH, K8s, Compress, Network, OS arch/kernel/memory,
> Proc ps/kill/lsof, File watch) moved to **[Trebejo](https://hex.pm/packages/trebejo)** v1.0.0.

## Quick Start

```elixir
def deps do
  [
    {:apero, "~> 3.0.0"}
  ]
end
```

## Modules

### File & Path
```elixir
Apero.File.dir?("lib")                                    # => true
Apero.File.file?("mix.exs")                               # => true
Apero.File.read("config.json")                            # => {:ok, content}
Apero.File.write("out.txt", "hello")                      # => :ok
Apero.File.atomic_write("out.txt", "atomic!")             # => :ok
Apero.File.checksum("mix.exs", :sha256)                   # => {:ok, digest}
Apero.File.copy("a.txt", "b.txt")                         # => {:ok, bytes}
Apero.File.generate_tree(["lib/", "test/"])               # => ASCII tree
```

### Cryptography
```elixir
Apero.Crypto.sha256("data")                               # => hex digest
Apero.Crypto.random_hex(16)                               # => random token
*`sha256/1`, `sha512/1`, and `md5/1` results are now cached in ETS for faster repeated calls.*
{:ok, ct} = Apero.Crypto.encrypt("secret")                # AES-256-GCM
{:ok, pt} = Apero.Crypto.decrypt(ct, key)
```

### Environment & Config
```elixir
Apero.Env.load(".env")                                    # load .env file
Apero.Conf.load("app.yaml")                               # {:ok, config}
```

### Cache
```elixir
Apero.Cache.put(:my_cache, :key, "value")
{:ok, value} = Apero.Cache.get(:my_cache, :key)
```

### Retry
```elixir
Apero.Retry.with(fn -> Api.call() end, max_retries: 3)
```

### OS & Proc (pure subset)
```elixir
Apero.OS.type()                                           # => :linux | :macos | :windows
Apero.OS.hostname()                                       # => "myhost"
Apero.Proc.command_exists?("git")                         # => true
Apero.Proc.vm_memory()                                    # => bytes
```

## Architecture

<!-- Added `Apero.Cache.Crypto` module that adds caching to cryptographic helpers -->

```
apero (pure stdlib)
  ├── File        — path ops, atomic I/O, trees, watcher GenServer
  ├── Crypto      — hashing (SHA-256/512, MD5), AES encryption, keys
  ├── Env / Conf  — environment variables, config files (JSON, YAML, TOML)
  ├── Cache       — in-memory ETS with TTL
  ├── Retry       — configurable retry with backoff
  ├── OS          — type detection, hostname (pure Erlang)
  └── Proc        — command availability, VM introspection (pure Elixir)
```

## What moved to Trebejo

| Apero (v2.x) | Trebejo (v1.0.0) |
|---|---|
| `Apero.Docker.*` | → `Trebejo.Docker.*` |
| `Apero.Git.*` | → `Trebejo.Git.*` / `Trebejo.Git.Local.*` |
| `Apero.SSH.*` | → `Trebejo.SSH.*` |
| `Apero.Kubernetes.*` | → `Trebejo.Kubernetes.*` |
| `Apero.Compress.*` | → `Trebejo.Compress.*` |
| `Apero.Network.*` | → `Trebejo.Network.*` |
| Apero.OS (arch, kernel, etc.) | → `Trebejo.OS.*` |
| Apero.Proc (ps, kill, lsof, etc.) | → `Trebejo.Proc.*` |
| Apero.File.watch | → `Trebejo.File.watch/3` |
| Apero.File.IO.disk_usage | → `Trebejo.File.IO.disk_usage/1` |

## License

MIT

Una versión en español de este README está disponible en [`docs/README.es.md`](docs/README.es.md).
