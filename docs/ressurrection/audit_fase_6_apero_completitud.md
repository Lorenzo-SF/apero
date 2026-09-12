# apero — audit completitud (iter-036)

> **Fecha**: 2026-09-12
> **Autor**: Mavis
> **Tamaño**: 4,417 LOC, ~45 módulos
> **Meta**: apero 100% terminado

---

## Estado actual (post iter-028 ressurrection_fase_1)

| Área | LOC | Estado |
|------|-----|--------|
| `apero.ex` (facade) | 70 | ✅ OK |
| `cache/` (AdapterMonitor, Supervisor, ETS) | ~250 | ✅ OK |
| `crypto/` (Cipher, Hash) | ~315 | ✅ OK |
| `file/` (atomic, io, path) | ~825 | ✅ OK (con fsync) |
| `http.ex` (HTTPoison wrapper) | 168 | ✅ OK (sin wrappers especulativos) |
| `rate_limit.ex` (token bucket) | ~320 | ✅ OK (con wait receive-loop) |
| `retry.ex` + `backoff.ex` | ~310 | ✅ OK |
| `conf.ex` + `conf/loader.ex` | ~254 | ✅ OK |
| `jsonl.ex` | 195 | ✅ OK |
| `atomic_file.ex` | 129 | ✅ OK |
| `env.ex` | 126 | ✅ OK |
| `clock.ex` | 115 | ✅ OK |
| `os.ex` | 100 | ✅ OK |
| `packages.ex` | 109 | ⚠️ verificar |
| `proc.ex` | ~80 | ⚠️ verificar |

## Gaps identificados (para iter-036)

### P1 — `Apero.Packages` no maneja errores consistentemente
**Archivo**: `lib/apero/packages.ex`
**Tipo**: reliability
**Impacto**: detecta apt/dnf/pacman/brew/port pero no maneja timeouts ni "not found"
explícitamente.  Returns `:ok` para todos los casos.

### P1 — `Apero.Clock` no tiene monotonic_ms/0 (ya tiene System.monotonic_time wrapper)
**Archivo**: `lib/apero/clock.ex`
**Tipo**: completeness
**Impacto**: revisar si `monotonic_ms/0` está implementado correctamente.

### P2 — `Apero.Http` post_json no soporta timeout explícito
**Archivo**: `lib/apero/http.ex`
**Tipo**: feature gap
**Impacto**: HTTPoison tiene timeout pero apero no lo expone en su API.

### P2 — `Apero.Conf.Loader` no soporta merge con defaults profundos
**Archivo**: `lib/apero/conf/loader.ex`
**Tipo**: feature gap
**Impacto**: cuando un archivo de config tiene keys ausentes, no merge con defaults.

### P3 — `Apero.Jsonl` no comprueba la presencia de archivo
**Archivo**: `lib/apero/jsonl.ex:113`
**Tipo**: minor
**Impacto**: `read_all/1` con archivo inexistente retorna `{:error, :enoent}` — está OK.
Pero `stream!/1` no maneja el caso.

### P2 — `Apero.RateLimit.allow?/2` race condition en primer init
**Archivo**: `lib/apero/rate_limit/bucket.ex`
**Tipo**: race condition
**Impacto**: dos procesos concurrentes pueden ambos pasar `Bucket.allow?` antes de
que se haya insertado el bucket.

---

## Plan iter-036

1. SPEC (este doc).
2. P1: `Apero.Packages` — añadir `available?/1` + `detect/0` con error handling.
3. P1: `Apero.Clock.monotonic_ms/0` — verificar implementación.
4. P2: `Apero.Http` — añadir `:timeout` opt a `post_json/4`.
5. P2: `Apero.Conf.Loader.deep_merge/2` — merge recursivo con defaults.
6. P3: `Apero.Jsonl` — `stream!/1` maneja archivo inexistente.
7. P2: `Apero.RateLimit.Bucket.allow?` race condition — usar `insert_new` con
   `read_concurrency`.
8. Tests: 6-8 nuevos tests por fix.
9. Documentar.

**Total estimado**: 1-2 horas, ~150 LOC de cambios + ~200 LOC de tests.
