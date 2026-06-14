# Apero

[![version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Lorenzo-SF/Apero)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.md)

A utility library for Elixir covering file operations, Git management, Docker/Podman containers, cryptography, environment handling, config files, OS detection, and process management.

## Quick Start

```elixir
def deps do
  [
    {:apero, path: "../apero"}
  ]
end
```

## Modules

### `Apero.VFS` — File Operations

Unified file, path, and watch operations.

```elixir
Apero.VFS.dir?("lib")               # => true
Apero.VFS.file?("mix.exs")          # => true
Apero.VFS.exists?("priv/data")      # => false

{:ok, content} = Apero.VFS.read("config/settings.json")
Apero.VFS.write("tmp/scratch.txt", "hello world")

# Checksums
Apero.VFS.checksum("mix.exs", :sha256)

# Temporary resources (auto-cleaned)
Apero.VFS.with_tmp_file(fn path ->
  process_file(path)
end)
```

### `Apero.Compress` — Compression

Archive and decompress files.

```elixir
Apero.Compress.zip("/tmp/backup.zip", ["lib/", "config/"])
Apero.Compress.unzip("/tmp/backup.zip", output: "extracted/")

Apero.Compress.tar("/tmp/archive.tar.gz", "lib/", compressed: :gzip)
Apero.Compress.untar("/tmp/archive.tar.gz", output: "unpacked/")
```

### `Apero.Git` — Git Operations

Repository management and Git commands.

```elixir
repo = %{url: "git@github.com:org/repo.git", path: "/tmp/repo"}

Apero.Git.ensure_clone(repo, "/tmp/workspace")
Apero.Git.add(repo.path, :all)
Apero.Git.commit(repo, "feat: add feature")
Apero.Git.push(repo.path, "main")

# Check for uncommitted changes
Apero.Git.has_uncommitted_changes?(repo.path)
```

### `Apero.Docker` — Docker/Podman

Container lifecycle management.

```elixir
Apero.Docker.up(cd: "infra/", build: true)
Apero.Docker.down(cd: "infra/", volumes: true)
Apero.Docker.restart(cd: "infra/", services: ["app"])

Apero.Docker.exec("app", ["mix", "ecto.migrate"], cd: "infra/")
```

### `Apero.Crypto` — Cryptography

Hashing, encryption, and secure random generation.

```elixir
Apero.Crypto.sha256("password")
Apero.Crypto.random_hex(16)

{:ok, ciphertext} = Apero.Crypto.encrypt("secret data")
{:ok, plaintext} = Apero.Crypto.decrypt(ciphertext, key)
```

### `Apero.Conf` — Config Files

Load and parse configuration files.

```elixir
{:ok, config} = Apero.Conf.load("config/settings.json")
{:ok, config} = Apero.Conf.load("config/app.yaml", format: :yaml)
```

### `Apero.Env` — Environment Variables

Environment variable handling.

```elixir
Apero.Env.load(".env")
Apero.Env.fetch!("DATABASE_URL")
```

### `Apero.OS` — OS Detection

System information and detection.

```elixir
Apero.OS.info()
# => %{type: :linux, arch: :x86_64, hostname: "server", distro: "Ubuntu", ...}

Apero.OS.in_container?()  # => true/false
```

### `Apero.Proc` — Process Management

Process utilities and command execution.

```elixir
Apero.Proc.command_exists?("git")  # => true
Apero.Proc.which("elixir")        # => "/usr/local/bin/elixir"

{:ok, processes} = Apero.Proc.ps()
```

### `Apero.Pkg` — Package Management

Package manager abstraction.

```elixir
Apero.Pkg.install("curl")
Apero.Pkg.update()
```

### `Apero.Cache` — Caching

In-memory caching with ETS backend.

```elixir
Apero.Cache.put(:my_cache, :key, "value")
{:ok, value} = Apero.Cache.get(:my_cache, :key)
```

## Architecture

Apero is organized into focused modules:

- **VFS** — File operations (read, write, copy, move, delete, glob, watch)
- **Compress** — Archive operations (zip, tar, gzip)
- **Git** — Git command wrappers
- **Docker** — Container lifecycle
- **Crypto** — Hashing and random generation
- **Conf** — Config file parsing (JSON, YAML, TOML)
- **Env** — .env file loading
- **OS** — Operating system detection
- **Proc** — Process and command utilities
- **Pkg** — Package manager interface
- **Cache** — In-memory caching

## License

MIT
