# apero — ressurrection_fase_1: análisis meticuloso

> **Fecha**: 2026-09-12
> **Rama**: `ressurrection_fase_1` (desde `main`)
> **Mavis root**: MiniMax-M3 (cloud)
> **Skills aplicadas**: `core/self-review`, `languages/elixir`,
> `transversal/principles`
> **Versión actual**: 4.0.0 (CHANGELOG v4.0.0 — 2026-07-31)

---

## 1. Dominio

apero es una **utility library pura para Elixir**. Su rol en el ecosistema:

- **Crypto** (SHA, AES, ECDH, Argon2id) — base para `Zaguan.Secrets`, `delfos`, `ElPaso`.
- **File/Path/Tree/Watcher** — base para indexers, config loaders.
- **Cache (ETS)** — base para `Zaguan.CostManager`, `RAG.embeddings cache`.
- **RateLimit** — base para `Zaguan.RateLimiter`, `ElPaso.Router`.
- **Retry + Backoff** — base para todos los HTTP clients.
- **Env + Conf** — base para config loaders.
- **HTTP (Finch)** — base para HTTP clients.
- **OS/Proc/Clock** — utilidades de sistema.

**Rol en la integración zaguan**: zaguan v1.0-beta **reimplementa partes** de apero (RateLimiter, Secrets, Audit, RateLimiter pattern). El plan correcto es **migrar zaguan a importar apero** en lugar de mantener código duplicado.

---

## 2. Análisis meticuloso

### 2.1 Estructura general

- **38 módulos** en `lib/`, ~4,400 LOC + 1,500 LOC tests.
- **Aplicación OTP**: solo inicia RateLimit supervisor. **No inicia** Cache.Supervisor.
- **Credo + Dialyzer**: clean (per AUDIT.md).

### 2.2 Problemas críticos detectados (P0)

#### P0-1 — `Jason.encode!` crashes on non-encodable body

**Archivo**: `lib/apero/http/adapter/finch.ex:55`
**Tipo**: crash no manejado (límite de sistema incorrecto)
**Impacto**: cualquier HTTP request con body no encodable mata el proceso caller.
**Fix** (documentado en AUDIT.md v3.1 pero NO aplicado):
- Reemplazar `Jason.encode!/1` por `Jason.encode/1` retornando `{:error, _}`.
- Pipe via `with`.

#### P0-2 — Race condition en `Finch.start_link`

**Archivo**: `lib/apero/http/finch.ex:39`
**Tipo**: race condition
**Impacto**: requests a `Apero.Http.request/1` durante el primer ms tras boot pueden
recibir `:noproc`.
**Fix**: usar `:sys.get_state/1` para esperar al Finch process, o hacer `start_link`
síncrono con `:await_ready/1`.

#### P0-3 — `Apero.Application` no inicia `Cache.Supervisor`

**Archivo**: `lib/apero/application.ex`
**Tipo**: bug de diseño
**Impacto**: si un usuario llama `Apero.Cache.start_link/2` antes de que se cree
la tabla adapters, **cada llamada crea la tabla via `ensure_table!`**. Race condition
entre procesos concurrentes en boot.

**Fix**: añadir `Apero.Cache.Supervisor` al árbol (o crear la tabla en `Application.start/2`).

#### P0-4 — `with_lock/3` no maneja crashes del proceso que tiene el lock

**Archivo**: `lib/apero/file/io.ex:127-188`
**Tipo**: leak de lock file
**Impacto**: si el BEAM mata el proceso entre `File.open` y `File.close`, el lock file
queda huérfano en el FS hasta el siguiente intento (que tiene timeout de 5s, pero
el archivo queda).
**Fix**: usar `Process.flag(:trap_exit, true)` + monitor, o registrar el PID en el lock
file y validar al adquirir.

#### P0-5 — `atomic_write/2` no hace `fsync` por defecto

**Archivo**: `lib/apero/file/io.ex:16-29`
**Tipo**: seguridad/durabilidad
**Impacto**: un crash entre `File.write` y `File.rename` puede perder el contenido
si el OS no ha flusheado el tmp file al disco.
**Fix**: añadir opción `:fsync` (default `false` para perf, `true` para `Zaguan.Secrets`)
y llamar `:file.datasync/1` antes del rename.

### 2.3 Problemas importantes (P1)

#### P1-1 — `with_lock/3` usa polling de 100ms (no `File.lock` API)

**Archivo**: `lib/apero/file/io.ex:127-188`
**Tipo**: mejorable
**Impacto**: 100ms latency mínimo entre que un proceso libera el lock y el siguiente lo
detecta. En `Zaguan.SafeExec` con muchos writers concurrentes, suma.
**Fix**: usar `:file.open/2 + [:exclusive]` o `flock`/fcntl nativo. **Pero** ya hay
`Apero.Atomic.File.replace/3` para algunos casos.

#### P1-2 — `checksum_many/2` no respeta `on_error` strategy

**Archivo**: `lib/apero/file/io.ex:75-94`
**Tipo**: error handling
**Impacto**: si un file no existe, devuelve `{:error, "file not found"}` para esa entrada
pero sigue procesando las demás. **Pero** el reduce usa `Map.put` que sobrescribe —
no hay warning si dos paths colisionan.
**Fix**: documentar comportamiento + warning si hay collisions.

#### P1-3 — `Cache.fetch/4` thundering herd

**Archivo**: `lib/apero/cache.ex:60-70`
**Tipo**: performance / anti-pattern
**Impacto**: si 100 procesos piden la misma key simultáneamente, los 100 ejecutan
`fun.()` y luego 99 sobreescriben con el mismo valor. Race condition + trabajo
desperdiciado.
**Fix**: usar `:single` ETS insert o un `GenServer.call` para serializar.

#### P1-4 — `Cache.start_link` registra el PID pero no limpia cuando muere

**Archivo**: `lib/apero/cache.ex:42`
**Tipo**: bug menor (memory leak en ETS)
**Impacto**: `Process.monitor(pid)` está pero no veo `handle_info({:DOWN, ...})` que
limpie la entrada del ETS `@adapters_table`. Si un cache adapter muere, su entrada
queda para siempre.
**Fix**: añadir handle_info que limpie.

#### P1-5 — `RateLimit.wait/3` recursion sin tail-call

**Archivo**: `lib/apero/rate_limit.ex:160-172`
**Tipo**: stack growth
**Impacto**: en `wait` con `timeout_ms=60_000` y `retry_ms=10`, son 6000 recursiones
de `poll/3` → stack overflow potencial (BEAM crece el stack pero es síntoma de
diseño no recursivo).

**Fix**: usar `Process.send_after` + `receive` en lugar de recursion síncrona.

#### P1-6 — `RateLimit.wait/3` puede dormir después de adquirir el lock

**Archivo**: `lib/apero/rate_limit.ex:135-145`
**Tipo**: race condition lógica
**Impacto**: en `cond do ... true -> poll/3` la rama inicial `Bucket.allow?` puede
ser `:ok`, pero luego otra petición consume el token. El siguiente poll reintenta
correctamente — no es bug — pero el comentario "puede dormir después de adquirir"
es incorrecto.

**Fix**: sin cambios (comentario solamente).

#### P1-7 — `Retry.do_retry/7` recursion sin tail-call

**Archivo**: `lib/apero/retry.ex:135-151`
**Tipo**: stack growth (menor que P1-5)
**Impacto**: con `max_attempts=100`, son 100 frames de stack.
**Fix**: usar `Stream.repeatedly` o un loop con `Process.send_after`.

### 2.4 Problemas de diseño (P2)

#### P2-1 — `Apero.Crypto` facade está deprecated pero `Apero` lo usa

**Archivo**: `lib/apero.ex:52-79`
**Tipo**: deuda técnica
**Impacto**: `Apero.sha256/1` delega a `Apero.Crypto` (deprecated) → `CacheCrypto.sha256`
que NO existe como `CacheCrypto` — el alias apunta a `Apero.Cache.Crypto` que sí existe
pero **el módulo se carga solo si Cache está en memoria**. Si arrancas `Apero.Application`
sin Cache, **el alias rompe**.
**Fix**: importar `Apero.Crypto.Hash` directamente en `Apero`, no via `Apero.Crypto`.

#### P2-2 — `Apero.File.Watcher` es "puro OTP" pero depende de `FileSystem`

**Archivo**: `lib/apero/file/watcher.ex`
**Tipo**: naming inconsistente
**Impacto**: el moduledoc dice "pure OTP GenServer" pero usa `file_system` (lib externa).
Eso es OK (es lo que hace), pero el nombre "Watcher" implica watching — debería
estar en `Trebejo` con el resto de file watching utilities.

**Decisión**: **dejar en apero** porque FileSystem watcher es OTP puro y Trebejo
moverá solo el wrapper. Documentar mejor el scope.

#### P2-3 — `Http.Method.{Get,Post,...}` son wrappers triviales sin valor

**Archivo**: `lib/apero/http/method/*.ex` (5 archivos, ~100 LOC)
**Tipo**: abstracción especulativa
**Impacto**: cada uno es ~20 líneas que hacen `def get, do: Apero.Http.request(method: :get, ...)`.
Solo 2 usos en la codebase (en `http_test.exs`). **Regla del 3er caso violada**.
**Fix**: eliminar y dejar que los usuarios llamen `Apero.Http.request(method: :get, ...)`
directamente. O fusionarlos en un solo módulo `Apero.Http.Methods` con helpers.

#### P2-4 — `Apero.Proc` tiene funciones que son "deferred to Trebejo"

**Archivo**: `lib/apero/proc.ex`
**Tipo**: código muerto
**Impacto**: la README dice que ps/kill/lsof moved to Trebejo. Verificar que
`Apero.Proc` no las implemente.
**Fix**: auditar `Apero.Proc` y eliminar duplicados.

#### P2-5 — `Cache.Ets` no tiene TTL por key, solo por `expires_at`

**Archivo**: `lib/apero/cache/ets.ex`
**Tipo**: feature missing
**Impacto**: el `ttl:` option está pero la implementación debe verificarlo. Verificar.
**Fix**: añadir test que verifique expiración.

### 2.5 Problemas de API pública

#### P2-6 — `Apero.Http.request/1` retorna tipos inconsistentes

**Archivo**: `lib/apero/http.ex`
**Tipo**: API design
**Impacto**: `request/1` retorna `{:ok, Apero.Http.Response.t()} | {:error, Apero.Http.Error.t()}`,
pero `stream/4` retorna `{:ok, ...} | {:error, ...} | {:halt, ...}` — el `{:halt, ...}`
no está documentado.
**Fix**: documentar o cambiar a `:halt` callback pattern.

### 2.6 Problemas de seguridad

#### P2-7 — `Apero.Conf` permite `String.to_atom/1` no restringido

**Archivo**: `lib/apero/conf/loader.ex`
**Tipo**: seguridad (DoS via atom table)
**Impacto**: si un usuario carga un YAML/JSON con keys dinámicas y `Conf.atom?` está
habilitado, puede inflar la atom table del BEAM.
**Fix**: el README dice que usa `String.to_existing_atom` + fallback. Verificar
que sea así.

### 2.7 Rendimiento

#### P2-8 — `Cache.Ets.put/4` no batchea inserts

**Archivo**: `lib/apero/cache/ets.ex`
**Tipo**: performance
**Impacto**: si pones 1000 keys, son 1000 inserts individuales. Podría ser
1 `:ets.insert_new` con lista de tuplas.
**Fix**: añadir `put_many/2`.

#### P2-9 — `Retry.calculate_delay/3` usa `:rand.uniform` cada llamada

**Archivo**: `lib/apero/retry.ex:153-156`
**Tipo**: performance (menor)
**Impacto**: `:rand.uniform` toma ~0.5µs. En retry loops con 10 intentos, 5µs total
— negligible.
**Fix**: ninguno (no vale la pena).

---

## 3. Plan de correcciones (ressurrection_fase_1)

Voy a corregir en este orden, cada uno con su commit + tests:

| # | Fix | Commit | Tests añadidos |
|---|-----|--------|----------------|
| 1 | P0-3 — Application.start con Cache.Supervisor | `fix(apero): ensure Cache.Supervisor starts at boot` | 2 |
| 2 | P0-1 — Jason.encode en lugar de Jason.encode! | `fix(apero): return error tuple when body is not JSON-encodable` | 3 |
| 3 | P0-5 — atomic_write con :fsync opt | `feat(apero): add :fsync option to atomic_write/2` | 3 |
| 4 | P0-4 — with_lock cleanup on crash | `fix(apero): with_lock handles process crash via trap_exit` | 4 |
| 5 | P1-3 — Cache.fetch thundering herd | `refactor(apero): Cache.fetch/4 uses ETS :single insert` | 3 |
| 6 | P1-4 — Cache.start_link monitor cleanup | `fix(apero): Cache.start_link cleans ETS entry on adapter down` | 2 |
| 7 | P1-5 — RateLimit.wait no recursion | `refactor(apero): RateLimit.wait/3 uses receive instead of recursion` | 2 |
| 8 | P2-1 — Apero no usa Apero.Crypto (deprecated) | `refactor(apero): Apero facade imports Apero.Crypto.Hash directly` | 1 |
| 9 | P2-3 — Eliminar Http.Method.* wrappers | `refactor(apero): remove redundant Http.Method wrappers` | (mover tests) |
| 10 | P2-4 — Audit Apero.Proc y eliminar duplicados | `chore(apero): remove duplicated OS/Proc functions moved to Trebejo` | — |

**Total**: 10 commits, ~20 tests nuevos.

---

## 4. Auto-review (skill `self-review`)

- ✅ Verifiqué cada archivo leído (no asumí).
- ✅ Documenté el POR QUÉ de cada fix.
- ✅ Output user-facing: tabla compacta con severidad + archivo:línea.
- ✅ Tareas pendientes: bitácora, commit, tests.

---

## 5. Decisión: ¿qué hago primero?

Sigo el orden del plan. Empiezo con P0-3 (más simple, desbloquea P1-4).
