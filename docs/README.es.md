# Apero

[![version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/Lorenzo-SF/Apero)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE.md)

**Librería de utilidades puras para Elixir** — sin ejecución de shell. Proporciona
operaciones de ficheros, criptografía, manejo de entorno/configuración, reintentos,
caché, y utilidades puras de SO/Procesos.

> Las operaciones con shell (Docker, Git, SSH, K8s, Compress, Network,
> OS arch/kernel/memoria, Proc ps/kill/lsof, File watch) se movieron a
> **[Trebejo](https://hex.pm/packages/trebejo)** v1.0.0.

## Inicio rápido

```elixir
def deps do
  [
    {:apero, "~> 3.0.0"}
  ]
end
```

## Módulos

### File & Path
```elixir
Apero.File.dir?("lib")                                    # => true
Apero.File.file?("mix.exs")                               # => true
Apero.File.read("config.json")                            # => {:ok, contenido}
Apero.File.write("salida.txt", "hola")                    # => :ok
Apero.File.atomic_write("salida.txt", "atómico!")         # => :ok
Apero.File.checksum("mix.exs", :sha256)                   # => {:ok, digest}
Apero.File.copy("a.txt", "b.txt")                         # => {:ok, bytes}
Apero.File.generate_tree(["lib/", "test/"])               # => árbol ASCII
```

### Cryptografía
```elixir
Apero.Crypto.sha256("datos")                              # => hex digest
Apero.Crypto.random_hex(16)                               # => token aleatorio
*Los resultados de `sha256/1`, `sha512/1` y `md5/1` se almacenan ahora en ETS para llamadas repetidas más rápidas.*
{:ok, ct} = Apero.Crypto.encrypt("secreto")               # AES-256-GCM
{:ok, pt} = Apero.Crypto.decrypt(ct, clave)
```

### Entorno y Configuración
```elixir
Apero.Env.load(".env")                                    # carga archivo .env
Apero.Conf.load("app.yaml")                               # {:ok, config}
```

### Caché
```elixir
Apero.Cache.put(:mi_cache, :clave, "valor")
{:ok, valor} = Apero.Cache.get(:mi_cache, :clave)
```

### Reintentos
```elixir
Apero.Retry.with(fn -> Api.llamar() end, max_retries: 3)
```

### SO y Proc (subconjunto puro)
```elixir
Apero.OS.type()                                           # => :linux | :macos | :windows
Apero.OS.hostname()                                       # => "miservidor"
Apero.Proc.command_exists?("git")                         # => true
Apero.Proc.vm_memory()                                    # => bytes
```

## Arquitectura

```
apero (stdlib pura)
  ├── File      — operaciones de ruta, I/O atómico, árboles, GenServer watcher
  ├── Crypto    — hashing (SHA-256/512, MD5), cifrado AES, claves
  ├── Env/Conf  — variables de entorno, archivos de config (JSON, YAML, TOML)
  ├── Cache     — ETS en memoria con TTL
  ├── Retry     — reintentos configurables con backoff
  ├── OS        — detección de tipo, hostname (Erlang puro)
  └── Proc      — disponibilidad de comandos, introspección VM (Elixir puro)
```

## Lo que se movió a Trebejo

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

## Licencia

MIT

An English version of this README is available at [`../README.md`](../README.md).
