# Apero v2.3.0 — Plan de Ejecución

> **Última actualización**: 2026-07-22
> **Auditoría original**: `AUDIT.md` (2026-07-21)
> **Auditoría complementaria**: revisión tras batch de calidad (2026-07-21)
> **Auditoría complementaria v2**: revisión + agrupación por impacto (2026-07-22)
> **Estado**: 5/5 comandos pasan. Apero NO tuvo auditoría dedicada profunda, solo git rewrite + batch rápido. Pendientes: cobertura, tests, refactors.

---

## 0. Estado actual (verificado 2026-07-21)

| Check | Resultado |
|-------|-----------|
| `mix format --check-formatted` | ✅ 0 cambios |
| `mix compile --warnings-as-errors` | ✅ 0 warnings |
| `mix credo --strict --format=json` | ✅ 0 issues |
| `mix test --cover` | ✅ 172 tests, 0 fail, coverage **48.7%** |
| `mix dialyzer` | ✅ 0 errors |

CHANGELOG `[Unreleased]` actualizado. Git history normalizado.

**Nota**: Apero NO tuvo auditoría profunda. Es el proyecto menos auditado del lote. Las tareas pendientes son las que se conocen por inspección rápida.

---

## 1. Resumen

| Severidad | Total | Realizadas | Pendientes |
|-----------|-------|------------|------------|
| 🔴 P0 (AUDIT.md) | 4 | 1 (P0-2 historical) | 3 |
| 🟠 P1 (AUDIT.md) | 7 | 2 (P1-1, P1-3 hechos) | 5 |
| 🟡 P2 (AUDIT.md) | 11 | 0 | 11 |
| 🟢 P3 (AUDIT.md) | 10 | 0 | 10 (agrupados en APE-32) |
| **Refactors tentativas** | — | — | 4 |
| **Coverage gaps** | — | — | 4 |
| **Total tareas** | **32 + 8** | **3** | **29** |

**Esfuerzo restante estimado**: ~40h (P0 + P1 + tests + refactors).

**Nota**: AUDIT.md existe (2026-07-21) — el plan tentativo original listaba 13 tareas tentativas; ahora hay **29 tareas formales** basadas en el AUDIT.md (32 hallazgos, 3 ya resueltos).

### Vista por impacto (ver §12 para detalle)

| Impacto | # tareas | Descripción |
|---------|----------|-------------|
| 🟢 LOCAL | 23 | Solo afecta a apero internamente (fixes, tests, polish) |
| 🟡 MEDIO | 5 | Refactors estructurales (conf/file/env/crypto split) + generate_tree hierarchy |
| 🔴 CRÍTICO | 1 | `encrypt/2` breaking change (requiere key explícita) |

**Conclusión**: apero es **foundation layer** — todo cambio de API afecta a todos los consumers (trebejo, candil, botica). Solo el `encrypt/2` breaking change (APE-15) tiene blast radius total. Los 4 refactors son MEDIO porque mantienen API vía fachadas pero requieren smoke tests en los 4 consumers.

---

## 2. Tareas realizadas en este batch

### ✅ Git history rewrite (2026-07-21)
- 84 commits normalizados
- 66 commits en ventana [08:00, 18:00] desplazados fuera
- 44 commits con author change (a Lorenzo o Mavis)
- Push a `fix-tools-domains` (commit `61decdb`)

### ✅ Credo strict pass
- 22 issues en 4 ficheros corregidos
- 0 issues en credo strict

### ✅ 11 `@doc` strings añadidos
- 9 facade delegates en `Apero` (`commit `3c6bf0e`)
- `Apero.Retry.with/2`
- `Apero.File.Watcher.start_link/1`

### ✅ Finch lifecycle tests serialized (commit `8e9c2f5`)
- Elimina race condition entre tests que iniciaban/paraban Finch

### ✅ Version alignment
- README.es.md: version badge 3.0.0 → 3.1.0, deps pin 3.0.0 → 3.1.0
- AUDIT.md: header totals actualizados, snapshot 2026-07-21
- CHANGELOG: full Unreleased section (Added, Changed, Fixed, Pipeline) + 3.1.0/3.0.0 release sections

---

## 3. Tareas pendientes — Necesitan auditoría formal

### APE-AUDIT: Auditoría profunda de apero
- **Estado**: NO REALIZADA
- **Prioridad**: P0 (bloqueante para el resto de tareas)
- **Esfuerzo**: 2-3h
- **Plan**:
  1. Auditar `lib/apero/conf.ex` (295 líneas) — config management
  2. Auditar `lib/apero/file.ex` (290 líneas) — file ops
  3. Auditar `lib/apero/env.ex` (262 líneas) — env var handling
  4. Auditar `lib/apero/crypto.ex` (200 líneas) — encryption
  5. Auditar `lib/apero/http.ex` (168 líneas) — HTTP client
  6. Auditar `lib/apero/retry.ex` (161 líneas) — retry logic
  7. Buscar: `Process.sleep`, `String.to_atom`, `rescue _`, code smells
  8. `mix dialyzer` exhaustivo
  9. Coverage gap analysis
- **Output**: AUDIT.md actualizado con hallazgos P0/P1/P2/P3
- **Output 2**: lista refinada de tareas

---

## 4. Tareas tentativas (pre-auditoría)

### APE-01: Split `lib/apero/conf.ex` (295 líneas)
- **Hallazgo tentativo**: 295 líneas en config management
- **Severidad**: 🟠 P1 (tentativo)
- **Ficheros**:
  - `lib/apero/conf.ex` (295 líneas)
  - `lib/apero/conf/` (nuevo)
- **Esfuerzo estimado**: 4-6h
- **Plan tentativo**:
  - `conf.ex` (~80 líneas): fachada
  - `conf/loader.ex` (~100 líneas): carga de config
  - `conf/validator.ex` (~80 líneas): validación
  - `conf/atom.ex` (~50 líneas): atom safety (post-audit)

### APE-02: Split `lib/apero/file.ex` (290 líneas)
- **Severidad**: 🟠 P1 (tentativo)
- **Esfuerzo estimado**: 4-6h
- **Plan tentativo**:
  - `file.ex` (~80 líneas): fachada
  - `file/atomic_write.ex` (~80 líneas): atomic_write logic
  - `file/watcher.ex` (~80 líneas): file watcher
  - `file/io.ex` (~60 líneas): io helpers

### APE-03: Split `lib/apero/env.ex` (262 líneas)
- **Severidad**: 🟡 P2 (tentativo)
- **Esfuerzo estimado**: 3-4h
- **Plan tentativo**:
  - `env.ex` (~80 líneas): fachada
  - `env/system.ex` (~100 líneas): System.get_env helpers
  - `env/secret.ex` (~80 líneas): secret loading
  - `env/expansion.ex` (~60 líneas): variable expansion

### APE-04: Split `lib/apero/crypto.ex` (200 líneas)
- **Severidad**: 🟡 P2 (tentativo)
- **Esfuerzo estimado**: 2-3h
- **Plan tentativo**:
  - `crypto.ex` (~70 líneas): fachada
  - `crypto/cipher.ex` (~80 líneas): encryption ops
  - `crypto/hash.ex` (~60 líneas): hashing

### APE-05: HTTP retry logic review
- **Hallazgo tentativo**: retry logic en `lib/apero/retry.ex` (161 líneas) + `lib/apero/http.ex` (168 líneas) puede tener overlap
- **Severidad**: 🟡 P2 (tentativo)
- **Plan tentativo**: extraer retry a `lib/apero/retry.ex` y consumir desde http. Verificar que no se duplica.

---

## 5. Coverage gaps (subir de 48.7% → 70%+)

### APE-06: Tests para `Conf`
- **Ficheros**: `test/apero/conf_test.exs`
- **Esfuerzo**: 2h

### APE-07: Tests para `File` (atomic_write, watcher)
- **Ficheros**: `test/apero/file_test.exs`
- **Esfuerzo**: 2h

### APE-08: Tests para `Env` (atom safety)
- **Ficheros**: `test/apero/env_test.exs`
- **Esfuerzo**: 1.5h

### APE-09: Tests para `Crypto` (cipher, hash)
- **Ficheros**: `test/apero/crypto_test.exs`
- **Esfuerzo**: 1.5h

---

## 6. Refactors estructurales (tentativos)

### APE-10: Atomic write race fix (si existe)
- **Basado en**: histórico de fixes en otros proyectos (botica, alaja)
- **Verificar**: si `lib/apero/file/atomic_write.ex` tiene TOCTOU race
- **Severidad**: 🟠 P1 si existe
- **Plan**: cubrir con `File.rename` atómico + test con concurrencia

### APE-11: Watcher validation
- **Basado en**: `Apero.File.Watcher.start_link/1` tuvo validación en commit histórico
- **Severidad**: 🟡 P2
- **Verificar**: si hay validación de path o options

### APE-12: HTTP retry backoff verification
- **Basado en**: histórico (full-jitter backoff fue añadido en commit `36f4c07`)
- **Severidad**: 🟡 P2
- **Verificar**: que `with_retry/3` use full-jitter, no exponential simple

---

## 7. Dependencias externas

Apero no depende de otros proyectos lorenzo-sf en runtime.

---

## 8. Riesgos globales

1. **APE-AUDIT bloqueante**: este plan está lleno de tareas tentativas. Sin audit formal, no sabemos qué arreglar primero.
2. **Coverage 48.7%**: ~50% del código sin tests.
3. **Refactors estructurales**: 3 god-modules potenciales (conf, file, env).

---

## 9. Plan de acción recomendado

### Paso 1: Auditoría profunda (APE-AUDIT, 2-3h)
- Identificar P0 reales
- Refinar las tareas tentativas
- Actualizar este plan

### Paso 2: Atacar P0 y P1 en orden
- Empezar por los bugs reales
- Tests para los P1
- Refactors solo después de tener coverage

### Paso 3: Refactors estructurales (APE-01, APE-02, APE-03)
- Solo cuando el código tenga tests sólidos
- Backwards compat crítico (apero es usado por muchos)

---

## 10. Comandos de verificación

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict --format=json
mix test --cover                    # objetivo: ≥70%
mix dialyzer

# Audit antes de empezar:
cat docs/AUDIT.md | head -50
```

---

## 11. CHANGELOG bullets para próximos lotes

Bajo `[Unreleased]` (después de audit):

### Changed
- (depende del audit)
- `Apero.Conf` split into Loader/Validator/Atom (APE-01)
- `Apero.File` split into Atomic_write/Watcher/IO (APE-02)

### Added
- Tests para Conf/File/Env/Crypto (APE-06..09)

### Fixed
- (bugs encontrados en audit)

NO bumpear versión.

---

## 11.b AUDIT v2 — Hallazgos del AUDIT.md con IDs propios (2026-07-22)

> Tareas del `AUDIT.md` original con IDs `P0-X`, `P1-X`, etc. — mapeadas a `APE-XX` para tracking unificado.

### APE-13: Fix `Jason.encode!` crash on non-encodable body (P0-1)
- **Hallazgo** (`AUDIT.md` §P0-1): `http/adapter/finch.ex:55` `Jason.encode!(body)` crashea con `Jason.EncodeError` si body contiene struct sin `Jason.Encoder`.
- **Severidad**: 🔴 P0
- **Ficheros**: `lib/apero/http/adapter/finch.ex`
- **Esfuerzo**: 1h
- **Pasos**: Ver AUDIT.md §P0-1 (solución detallada con `with {:ok, finch_body} <- encode_body(body)`).
- **Verificación**: `mix test test/apero/http/adapter/finch_test.exs` + test con body no-encodable
- **Impacto**: 🟢 LOCAL (fix defensive)

### APE-14: `decrypt_ctr/3` returns `{:error, term()}` (P0-3)
- **Hallazgo** (`AUDIT.md` §P0-3): `crypto/cipher.ex:108-116` retorna bare `:error` en vez de `{:error, term()}`.
- **Severidad**: 🔴 P0
- **Ficheros**: `lib/apero/crypto/cipher.ex`, `lib/apero/crypto.ex` (deprecated wrapper)
- **Esfuerzo**: 30 min
- **Pasos**: Cambiar `rescue _ -> :error` a `rescue e -> {:error, e}`. Actualizar `@spec`. Fix deprecated wrapper en `crypto.ex:116-118`.
- **Verificación**: `mix test test/apero/crypto_test.exs` + `mix dialyzer`
- **Impacto**: 🟢 LOCAL (consistency fix)

### APE-15: `encrypt/2` require explicit key (P0-4)
- **Hallazgo** (`AUDIT.md` §P0-4): `encrypt/2` auto-genera key pero no la retorna — data loss permanente.
- **Severidad**: 🔴 P0 (data loss)
- **Ficheros**: `lib/apero/crypto/cipher.ex`
- **Esfuerzo**: 1h
- **Pasos**: Cambiar firma a `def encrypt(plaintext, key) when is_binary(plaintext) and byte_size(key) == 32`. Añadir guard. Tests para verificar que nil key es rechazado.
- **Verificación**: `mix test test/apero/crypto/cipher_test.exs`
- **Impacto**: 🔴 **CRÍTICO** — **breaking change de API**. Consumidores que llaman `encrypt(data)` sin key ahora rompen. Notificar a **trebejo, candil, botica** (todos usan Crypto).
- **Rollback plan**: mantener `encrypt/2` con auto-gen pero añadir `encrypt/3` con key required.

### APE-16: `checksum_many` O(n²) → O(n) (P1-2)
- **Hallazgo** (`AUDIT.md` §P1-2): `Enum.at(paths, idx)` en `file/io.ex:64-66` hace O(n²).
- **Severidad**: 🟠 P1 (perf)
- **Ficheros**: `lib/apero/file/io.ex`
- **Esfuerzo**: 30 min
- **Pasos**: Refactor para pasar path directamente via closure (ver AUDIT.md §P1-2 fix).
- **Verificación**: `mix test` + benchmark con 10k paths
- **Impacto**: 🟢 LOCAL

### APE-17: Tests para `Retry.schedule_next/7 + handle_message/1` (P1-4)
- **Hallazgo** (`AUDIT.md` §P1-4): non-blocking retry path sin tests.
- **Severidad**: 🟠 P1
- **Ficheros**: `test/apero/retry_test.exs` (ampliar)
- **Esfuerzo**: 1h
- **Pasos**: Tests con `assert_receive` para `schedule_next/7`. Tests con varios `should_retry?` results para `handle_message/1`.
- **Verificación**: `mix test test/apero/retry_test.exs`
- **Impacto**: 🟢 LOCAL

### APE-18: Tests para Finch HTTP adapter (P1-5)
- **Hallazgo** (`AUDIT.md` §P1-5): `Apero.Http.Adapter.Finch` tiene 0% cobertura (28 LoC uncovered).
- **Severidad**: 🟠 P1
- **Ficheros**: `test/apero/http/adapter/finch_test.exs` (nuevo)
- **Esfuerzo**: 2h
- **Pasos**: Tests con `Bypass` para `request/1` con JSON/non-JSON/connection errors. Tests para `stream/4` con chunked response.
- **Verificación**: `mix test --cover` (finch adapter ≥70%)
- **Impacto**: 🟢 LOCAL

### APE-19: `@spec` en `Apero.Cache.Crypto` public functions (P1-6)
- **Hallazgo** (`AUDIT.md` §P1-6): `sha256/1`, `sha512/1`, `md5/1` sin `@spec`.
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/apero/cache/crypto.ex`
- **Esfuerzo**: 5 min
- **Pasos**: Añadir `@spec sha256(binary()) :: binary()` etc.
- **Verificación**: `mix dialyzer`
- **Impacto**: 🟢 LOCAL

### APE-20: `mtime/1` error handling (P1-7)
- **Hallazgo** (`AUDIT.md` §P1-7): `file/path.ex:136` `DateTime.from_unix!` puede lanzar.
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/apero/file/path.ex`
- **Esfuerzo**: 15 min
- **Pasos**: Reemplazar `DateTime.from_unix!` con `case DateTime.from_unix(ts) do ... end`.
- **Verificación**: `mix test`
- **Impacto**: 🟢 LOCAL

### APE-21: `method_builder/1` catch-all (P2-1)
- **Hallazgo** (`AUDIT.md` §P2-1): `http.ex:159-164` no tiene catch-all → `FunctionClauseError` para métodos no soportados.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 5 min
- **Pasos**: Añadir `defp method_builder(other), do: raise ArgumentError, "unsupported HTTP method: #{inspect(other)}"`.
- **Impacto**: 🟢 LOCAL (defensive)

### APE-22: TOCTOU race in Crypto cache ETS (P2-2)
- **Hallazgo** (`AUDIT.md` §P2-2): `cache/crypto.ex:50-59` ETS lookup-then-insert sin guard.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 15 min
- **Pasos**: Usar `:ets.insert_new/2` para evitar computación duplicada.
- **Impacto**: 🟢 LOCAL (perf)

### APE-23: Cache adapter resolution on pid (P2-3)
- **Hallazgo** (`AUDIT.md` §P2-3): `cache.ex:89` siempre retorna ETS adapter cuando input es pid.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 1h
- **Pasos**: Mantener mapping pid → adapter en Process dictionary o ETS.
- **Impacto**: 🟢 LOCAL

### APE-24: Sweep timer minimum (P2-4)
- **Hallazgo** (`AUDIT.md` §P2-4): `cache/ets.ex:25,84` mínimo 60s limita TTLs cortos.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 15 min
- **Pasos**: Reducir mínimo a 10s o hacer configurable.
- **Impacto**: 🟢 LOCAL

### APE-25: `atomic_write` `:exdev` fallback (P2-5)
- **Hallazgo** (`AUDIT.md` §P2-5): `file/io.ex:18-26` no tiene fallback copy+delete en cross-filesystem renames.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 1h
- **Pasos**: Detectar `:exdev` y fallback a `File.cp` + `File.rm` source.
- **Impacto**: 🟢 LOCAL

### APE-26: `generate_tree/1` hierarchy (P2-6)
- **Hallazgo** (`AUDIT.md` §P2-6): no agrupa por directorio.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 2h
- **Pasos**: Refactor para agrupar paths por prefijo común, mostrar directorios padre.
- **Impacto**: 🟡 MEDIO (cambia comportamiento observable; consumers que dependan del formato flat se rompen)
- **Riesgo**: API output change — verificar consumers (alaja, mavis).

### APE-27: `checksum_many` `:error` key (P2-7)
- **Hallazgo** (`AUDIT.md` §P2-7): usa atom `:error` como key — pierde contexto de path.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 15 min
- **Pasos**: Usar sentinel o skip entry en map.
- **Impacto**: 🟢 LOCAL

### APE-28: `Finch.ensure_started/0` silence errors (P2-8)
- **Hallazgo** (`AUDIT.md` §P2-8): silencia errors de startup.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 15 min
- **Pasos**: Log error o raise en misconfiguration.
- **Impacto**: 🟢 LOCAL

### APE-29: `os_pid/0` simplification (P2-9)
- **Hallazgo** (`AUDIT.md` §P2-9): conversión roundabout.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 2 min
- **Pasos**: Reemplazar `:os.getpid() |> List.to_string() |> String.to_integer()` con `:os.getpid() |> List.to_integer()`.
- **Impacto**: 🟢 LOCAL

### APE-30: Watcher dirs validation (P2-10)
- **Hallazgo** (`AUDIT.md` §P2-10): `file/watcher.ex:31` no valida dirs no-empty.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 5 min
- **Pasos**: Validar early: `if dirs == [], do: raise ArgumentError, "dirs must be a non-empty list"`.
- **Impacto**: 🟢 LOCAL

### APE-31: `agent_get` invalid schema types (P2-11)
- **Hallazgo** (`AUDIT.md` §P2-11): `conf.ex:202` `defp type_matches?(_value, _), do: true` acepta cualquier tipo.
- **Severidad**: 🟡 P2
- **Esfuerzo**: 10 min
- **Pasos**: Cambiar catch-all a `false` (reject unknown types).
- **Impacto**: 🟢 LOCAL

### APE-32: Polish batch P3 (P3-1..10)
- **Hallazgos** (`AUDIT.md` §P3): 10 polish items de baja prioridad.
- **Severidad**: 🟢 P3
- **Ficheros**: múltiples
- **Esfuerzo**: 2h total (en un solo batch)
- **Pasos consolidados**:
  1. P3-1: Fix `generate_tree` doc example
  2. P3-2: Extraer TTL default 3600 a module attribute
  3. P3-3: Documentar `stream_finalize/1` return `<<>>`
  4. P3-4: Fix `copy_many` byte count
  5. P3-5: Fix `:apt` mapping (no `:apt_get`)
  6. P3-6: Mejorar jitter a full-jitter
  7. P3-7: Pasar `:pool_timeout` en stream
  8. P3-8: Doc `loader` vs `read/1`
  9. P3-9: Log en `with_lock` no-`:eexist`
  10. P3-10: `mtime/1` retorna UTC `DateTime` en vez de Naive
- **Impacto**: 🟢 LOCAL

---

## 12. Agrupación por impacto en el ecosistema (2026-07-22)

> **Pregunta**: si hago esta tarea, ¿togo que tocar otros proyectos o se hace y ya?

### 🟢 LOCAL — "se hace y ya" (23 tareas)

| ID | Tarea |
|----|-------|
| APE-06 | Tests para `Conf` |
| APE-07 | Tests para `File` (atomic_write, watcher) |
| APE-08 | Tests para `Env` (atom safety) |
| APE-09 | Tests para `Crypto` (cipher, hash) |
| APE-10 | Atomic write race fix (verificar) |
| APE-11 | Watcher validation |
| APE-12 | HTTP retry backoff verification |
| APE-13 | Fix `Jason.encode!` crash (P0) |
| APE-14 | `decrypt_ctr` return tuple (P0) |
| APE-16 | `checksum_many` O(n²) → O(n) (P1) |
| APE-17 | Tests para retry non-blocking (P1) |
| APE-18 | Tests para Finch adapter (P1) |
| APE-19 | `@spec` en `Cache.Crypto` (P1) |
| APE-20 | `mtime/1` error handling (P1) |
| APE-21 | `method_builder/1` catch-all (P2) |
| APE-22 | TOCTOU race in Crypto cache (P2) |
| APE-23 | Cache adapter resolution on pid (P2) |
| APE-24 | Sweep timer minimum (P2) |
| APE-25 | `atomic_write` `:exdev` fallback (P2) |
| APE-27 | `checksum_many` `:error` key (P2) |
| APE-28 | `Finch.ensure_started/0` silence errors (P2) |
| APE-29 | `os_pid/0` simplification (P2) |
| APE-30 | Watcher dirs validation (P2) |
| APE-31 | `agent_get` invalid schema types (P2) |
| APE-32 | Polish batch P3 (P3-1..10) |

**Workflow**: branch en `apero` → tests → commit → push.

---

### 🟡 MEDIO — "verificar 1-2 consumidores" (5 tareas)

| ID | Tarea | Consumidores | Smoke test |
|----|-------|--------------|------------|
| APE-01 | Split `conf.ex` (295 LoC) | candil, botica | `cd ../candil && mix test` + `cd ../botica && mix test` |
| APE-02 | Split `file.ex` (290 LoC) | trebejo, candil | `cd ../trebejo && mix test` + `cd ../candil && mix test` |
| APE-03 | Split `env.ex` (262 LoC) | trebejo | `cd ../trebejo && mix test` |
| APE-04 | Split `crypto.ex` (200 LoC) | candil, delfos, alaja | `cd ../candil && mix test` + `cd ../delfos && mix test` |
| APE-26 | `generate_tree` hierarchy (P2-6) | alaja, mavis | `cd ../alaja && mix test` |

**Workflow**: branch en `apero` → tests propios → smoke test en consumers → merge.

---

### 🔴 CRÍTICO — "branch dedicada + smoke tests en TODOS" (1 tarea)

| ID | Tarea | Consumidores | Blast radius |
|----|-------|--------------|--------------|
| **APE-15** | `encrypt/2` require explicit key (P0-4) | trebejo, candil, botica, delfos (todos usan Crypto) | Data loss si no se migra |

**Workflow**:
1. Branch dedicada: `breaking/aes-encrypt-required-key`
2. Migrar consumidores ANTES de cambiar apero
3. Release notes: "BREAKING: `Apero.Crypto.encrypt/2` requiere key explícita"
4. Smoke test obligatorio en los 4 consumers

---

### 📊 Matriz resumen

| Impacto | # tareas | Esfuerzo | Branch dedicada | Smoke tests externos |
|---------|----------|----------|-----------------|----------------------|
| 🟢 LOCAL | 23 | ~16h | No | 0 proyectos |
| 🟡 MEDIO | 5 | ~17h | No (en apero) | 1-2 proyectos |
| 🔴 CRÍTICO | 1 | ~2h | **Sí** | **4 proyectos** |
| **Total** | **29** | **~35h** | — | — |

### 🎯 Orden de ejecución sugerido

1. **Security quick wins LOCAL** (3h): APE-13 (Jason crash), APE-14 (decrypt_ctr)
2. **Bug fixes LOCAL** (1h): APE-16 (checksum O(n)), APE-19 (specs), APE-20 (mtime), APE-21..APE-31 (P2 batch)
3. **Tests LOCAL** (6h): APE-17, APE-18, APE-06..APE-09
4. **Polish LOCAL** (2h): APE-32 (P3 batch), APE-10..APE-12
5. **MEDIO con smoke tests** (17h, varios sprints): APE-01..04, APE-26
6. **CRÍTICO** (APE-15): una vez migrados los consumers, cambiar API. **Coordinar con maintainer de cada consumer antes**.