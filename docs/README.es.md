# Apero

[![version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Lorenzo-SF/Apero)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.md)

Apero es una librería de utilidades para Elixir que cubre operaciones de ficheros, gestión de Git, contenedores Docker/Podman, criptografía, manejo de variables de entorno, ficheros de configuración, detección de SO y gestión de procesos.

---

## Inicio rápido

```elixir
def deps do
  [
    {:apero, path: "../apero"}
  ]
end
```

---

## Módulos

### `Apero.VFS` — Operaciones de ficheros

Operaciones unificadas de ficheros, rutas y observación de cambios.

```elixir
Apero.VFS.dir?("lib")               # => true
Apero.VFS.file?("mix.exs")          # => true
Apero.VFS.exists?("priv/datos")     # => false

{:ok, contenido} = Apero.VFS.read("config/ajustes.json")
Apero.VFS.write("tmp/prueba.txt", "hola mundo")

# Checksums
Apero.VFS.checksum("mix.exs", :sha256)

# Recursos temporales (limpieza automática)
Apero.VFS.with_tmp_file(fn ruta ->
  exportar_datos(ruta)
end)
```

---

### `Apero.Compress` — Compresión

Archive y descompress de ficheros.

```elixir
Apero.Compress.zip("/tmp/backup.zip", ["lib/", "config/"])
Apero.Compress.unzip("/tmp/backup.zip", output: "extraido/")

Apero.Compress.tar("/tmp/archivo.tar.gz", "lib/", compressed: :gzip)
Apero.Compress.untar("/tmp/archivo.tar.gz", output: "desempaquetado/")
```

---

### `Apero.Git` — Operaciones Git

Gestión de repositorios, clonado, staging, commits y sincronización.

```elixir
repo = %{url: "git@github.com:org/repo.git", path: "/tmp/repo"}

Apero.Git.ensure_clone(repo, "/tmp/espacio")
Apero.Git.add(repo.path, :all)
Apero.Git.commit(repo, "feat: añadir feature")
Apero.Git.push(repo.path, "main")

# Verificar cambios sin commit
Apero.Git.has_uncommitted_changes?(repo.path)
```

---

### `Apero.Docker` — Docker/Podman

Gestión del ciclo de vida de contenedores Docker/Podman.

```elixir
Apero.Docker.up(cd: "infra/", build: true)
Apero.Docker.down(cd: "infra/", volumes: true)
Apero.Docker.restart(cd: "infra/", services: ["app"])

Apero.Docker.exec("app", ["mix", "ecto.migrate"], cd: "infra/")
```

---

### `Apero.Crypto` — Criptografía

Hashing, cifrado y generación aleatoria segura.

```elixir
Apero.Crypto.sha256("hola")
Apero.Crypto.random_hex(16)

{:ok, cifrado} = Apero.Crypto.encrypt("datos sensibles", clave)
{:ok, "datos sensibles"} = Apero.Crypto.decrypt(cifrado, clave)
```

---

### `Apero.Conf` — Ficheros de configuración

Carga y parseo de ficheros JSON, YAML y TOML.

```elixir
{:ok, cfg} = Apero.Conf.load("config/ajustes.json")
{:ok, cfg} = Apero.Conf.load("config/app.yaml", format: :yaml)
```

---

### `Apero.Env` — Variables de entorno

Manejo de variables de entorno y ficheros `.env`.

```elixir
Apero.Env.load(".env")
Apero.Env.fetch!("DATABASE_URL")
```

---

### `Apero.OS` — Detección del SO

Información y detección del sistema operativo.

```elixir
Apero.OS.info()
# => %{type: :linux, arch: :x86_64, hostname: "servidor", distro: "Ubuntu", ...}

Apero.OS.in_container?()  # => true/false
```

---

### `Apero.Proc` — Gestión de procesos

Utilidades de procesos y ejecución de comandos.

```elixir
Apero.Proc.command_exists?("git")  # => true
Apero.Proc.which("elixir")        # => "/usr/local/bin/elixir"

{:ok, procesos} = Apero.Proc.ps()
```

---

### `Apero.Pkg` — Gestor de paquetes

Abstracción del gestor de paquetes para múltiples distribuciones.

```elixir
Apero.Pkg.install("curl")
Apero.Pkg.update()
```

---

### `Apero.Cache` — Caché

Caché en memoria con backend ETS.

```elixir
Apero.Cache.put(:mi_cache, :clave, "valor")
{:ok, valor} = Apero.Cache.get(:mi_cache, :clave)
```

---

## Arquitectura

Apero está organizado en módulos enfocados:

- **VFS** — Operaciones de ficheros (lectura, escritura, copia, movimiento, eliminación, glob, watch)
- **Compress** — Operaciones de archivo (zip, tar, gzip)
- **Git** — Wrappers de comandos Git
- **Docker** — Ciclo de vida de contenedores
- **Crypto** — Hashing y generación aleatoria
- **Conf** — Parseo de ficheros de configuración (JSON, YAML, TOML)
- **Env** — Carga de ficheros .env
- **OS** — Detección del sistema operativo
- **Proc** — Utilidades de procesos y comandos
- **Pkg** — Interfaz del gestor de paquetes
- **Cache** — Caché en memoria

---

## Licencia

MIT
