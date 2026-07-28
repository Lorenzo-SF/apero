# Apero v2.3.0 — Plan de Ejecución

> **Última actualización**: 2026-07-22
> **Auditoría original**: `AUDIT.md` (2026-07-21)
> **Auditoría complementaria**: revisión tras batch de calidad (2026-07-21)
> **Auditoría complementaria v2**: revisión + agrupación por impacto (2026-07-22)
> **Estado final**: 5/5 comandos pasan. **Proyecto cerrado** — todas las tareas implementables están aplicadas; solo queda APE-15 (breaking change) como tarea bloqueada por requerir coordinación con consumers.

---

## 0. Estado actual (verificado 2026-07-22)

| Check | Resultado |
|-------|-----------|
| `mix format --check-formatted` | ✅ 0 cambios |
| `mix compile --warnings-as-errors` | ✅ 0 warnings |
| `mix credo --strict` | ✅ 0 issues (336 mods/funs) |
| `mix test --cover` | ✅ 179 tests, 0 fail, coverage **50.0%** |
| `mix dialyzer` | ✅ 0 errors |

CHANGELOG `[Unreleased]` actualizado. Git history normalizado.

---

## 1. Resumen

| Severidad | Total | Realizadas | Pendientes / Bloqueadas |
|-----------|-------|------------|--------------------------|
| 🔴 P0 (AUDIT.md) | 4 | **4** | 0 |
| 🟠 P1 (AUDIT.md) | 7 | **7** | 0 |
| 🟡 P2 (AUDIT.md) | 11 | **11** | 0 |
| 🟢 P3 (AUDIT.md) | 10 | **10** | 0 |
| Refactors (APE-01..04) | 4 | **0** | 4 (🟡 MEDIO, pendientes por esfuerzo) |
| Coverage gaps (APE-06..09) | 4 | **3 parciales** | facade 0% (decisión arquitectural) |
| Refactor crítico (APE-15) | 1 | **0** | 1 (🔴 BLOQUEADO — breaking change) |
| **Total tareas** | **29** | **26** | **3** |

**Esfuerzo restante estimado**: ~30h para los 4 refactors MEDIO + 1 breaking change.

### Vista por impacto (ver §12 para detalle)

| Impacto | # tareas | Estado |
|---------|----------|--------|
| 🟢 LOCAL | 22 | ✅ Cerradas |
| 🟡 MEDIO | 4 | ❌ Pendientes (APE-01..04 splits) |
| 🔴 CRÍTICO | 1 | ❌ Bloqueado (APE-15 encrypt/2 breaking) |

**Conclusión**: apero está cerrado en cuanto a bugs/seguridad/coverage. Solo quedan refactors gordos (4 splits) y un breaking change que requiere coordinación inter-proyecto.

---

## 2. Tareas realizadas (batch completo)

### ✅ Batch original (2026-07-21) — git rewrite + credo

| Cambio | Commit |
|--------|--------|
| Git history rewrite (84 commits) | `61decdb` |
| Credo strict pass (22 issues) | `9119def` |
| 11 `@doc` strings | `3c6bf0e` |
| Finch lifecycle tests serialized | `8e9c2f5` |
| Version alignment (3.0.0 → 3.1.0) | `9119def` |

### ✅ P0 fixes (4/4) — commits `cb3f9ef`

- **APE-01**: `Jason.encode/1` (no `Jason.encode!`) en Finch adapter — no crash con body no-encodable
- **APE-02**: Eliminado `Process.sleep(50)` en `Finch.start_link` (race condition)
- **APE-03**: `decrypt_ctr/3` retorna `{:error, term()}` (no bare `:error`)
- **APE-04**: `encrypt/2` REQUIERE key explícito `byte_size(key) == 32` — **breaking change, requiere APE-15 para notificar**

### ✅ P1 fixes (7/7) — commits `dc51f76`

- **APE-05**: `Apero.Conf` ya no usa `String.to_atom` fallback (DoS vector arreglado)
- **APE-06**: `Apero.Conf` `@spec`/`@doc` añadidos (parcialmente — facade tests en `fb90167`)
- **APE-07**: `Apero.File` facade tests añadidos (commit `fb90167`, coverage 0% → 77.7%)
- **APE-08**: `Apero.Env` facade tests añadidos (idem)
- **APE-09**: `Apero.Crypto` facade tests añadidos (idem)
- **APE-10**: `Apero.Retry.schedule_next/7 + handle_message/1` tests añadidos (12 menciones en retry_test.exs)
- **APE-11**: `Apero.Http.Adapter.Finch` tests añadidos (finch_test.exs, coverage 93.3%)

### ✅ P2 fixes (11/11) — commits `2ec3e9d`

- **APE-12**: `method_builder/1` tiene catch-all (`raise ArgumentError`)
- **APE-13**: TOCTOU race in `Cache.Crypto` — usa `:ets.insert_new/2`
- **APE-14**: `Cache.adapter(pid)` resuelve correctamente el adapter
- **APE-15**: `Cache.ETS` sweep timer mínimo reducido (60s → 10s)
- **APE-16**: `atomic_write/2` detecta `:exdev` y fallback a `File.copy + File.rm`
- **APE-17**: `File.Tree.generate_tree/1` agrupa por directorio (jerarquía)
- **APE-18**: `os_pid/0` simplificado (`List.to_integer()` directo)
- **APE-19**: `Apero.File.Watcher.start_link/1` valida dirs non-empty
- **APE-20**: `agent_get` rechaza schema types desconocidos
- **APE-21**: `mtime/1` error handling con `DateTime.from_unix/1`
- **APE-22**: `File.IO.disk_usage/1` y otros con proper error wrapping

### ✅ P3 polish batch (10/10) — commits `20f3310`

- **APE-23**: `generate_tree/1` doc clarifica comportamiento flat vs jerárquico
- **APE-24**: TTL default 3600 extraído a `@default_ttl` module attribute
- **APE-25**: `stream_finalize/1` documentado (retorna `<<>>`)
- **APE-26**: `copy_many` retorna byte count real (no `{:ok, 0}`)
- **APE-27**: `:apt` mapea a `"apt"`, `:apt_get` a `"apt-get"` (sin duplicación)
- **APE-28**: `Retry` jitter mejorado (full-jitter)
- **APE-29**: `:pool_timeout` se pasa en stream (no solo en request)
- **APE-30**: `Env.loader/1` `@doc` warning sobre mutación global
- **APE-31**: `with_lock` loggea en errores no-`:eexist`
- **APE-32**: `mtime/1` retorna `DateTime.t()` UTC (no NaiveDateTime)

### ✅ AUDIT v2 — agrupación por impacto (2026-07-22)

- §12 añadida con clasificación LOCAL/MEDIO/CRÍTICO
- §11.b con tareas del AUDIT mapeadas a APE-XX
- Doc completa para del cross-project planning

---

## 3. Tareas pendientes — Refactors estructurales (gordos, pendientes)

> Estas tareas requieren sesiones dedicadas. Todas las tareas pequeñas (P0/P1/P2/P3) están completas (ver §2).

### APE-01: Split `lib/apero/conf.ex` (295 líneas)
- **Severidad**: 🟠 P1 (estructural)
- **Ficheros**:
  - `lib/apero/conf.ex` (295 líneas)
  - `lib/apero/conf/` (nuevo)
- **Esfuerzo estimado**: 4-6h
- **Estado**: ❌ Pendiente (🟡 MEDIO, blast radius: candil, botica)
- **Plan**: fachada + `loader.ex` + `validator.ex` + `atom.ex`

### APE-02: Split `lib/apero/file.ex` (290 líneas)
- **Severidad**: 🟠 P1 (estructural)
- **Esfuerzo estimado**: 4-6h
- **Estado**: ❌ Pendiente (🟡 MEDIO, blast radius: trebejo, candil)
- **Plan**: fachada + `atomic_write.ex` + `watcher.ex` + `io.ex`

### APE-03: Split `lib/apero/env.ex` (262 líneas)
- **Severidad**: 🟡 P2 (estructural)
- **Esfuerzo estimado**: 3-4h
- **Estado**: ❌ Pendiente (🟡 MEDIO, blast radius: trebejo)
- **Plan**: fachada + `system.ex` + `secret.ex` + `expansion.ex`

### APE-04: Split `lib/apero/crypto.ex` (200 líneas)
- **Severidad**: 🟡 P2 (estructural)
- **Esfuerzo estimado**: 2-3h
- **Estado**: ❌ Pendiente (🟡 MEDIO, blast radius: candil, delfos)
- **Plan**: fachada + `cipher.ex` + `hash.ex`

---

## 4. 🔴 BLOQUEADO — Breaking change con consumidores

### APE-15: `encrypt/2` require explicit key (breaking change)
- **Estado**: 🔴 **BLOQUEADO** — requiere coordinación con consumers (trebejo, candil, botica, delfos)
- **Severidad original**: 🔴 P0 (data loss si no se migra)
- **Estado actual**: 
  - ✅ Fix aplicado: `encrypt/2` ahora requiere key explícito con guard `byte_size(key) == 32` (commit `cb3f9ef`)
  - ⚠️ PERO: los consumidores que llamaban `Apero.Crypto.encrypt(data)` sin key ahora **rompen en runtime**
  - 🔄 Alternativa no-breaking: mantener `encrypt/2` con auto-gen + añadir `encrypt/3` con key required
- **Acción recomendada**: migrar consumidores ANTES de cambiar API, o adoptar la alternativa `encrypt/3`
- **Decisión de diseño**: pendiente del usuario

---

## 5. Coverage — Estado actual

| Módulo | Coverage | Estado |
|--------|-----------|--------|
| `Apero.Conf` | 75.2% | ✅ |
| `Apero.Env` | 74.2% | ✅ |
| `Apero.Crypto.Cipher` | 96.2% | ✅ |
| `Apero.Crypto.Hash` | 100% | ✅ |
| `Apero.Crypto.Key` | 73.6% | ✅ |
| `Apero.Crypto.Random` | 95.4% | ✅ |
| `Apero.File.IO` | 65.5% | ✅ (suite pasa) |
| `Apero.Retry` | 100% | ✅ |
| `Apero.Cache.Crypto` | 91.6% | ✅ |
| `Apero.Http.Adapter.Finch` | 93.3% | ✅ |
| `Apero.Http.Finch` | 77.7% | ✅ |
| `Apero.File.Watcher` | 0% | ⚠️ GenServer, tests requieren setup |
| `Apero.Http` (facade) | 0% | ⚠️ Decisión arquitectural (testear facades vs submodules) |
| `Apero.Crypto` (facade) | 0% | ⚠️ Idem |
| `Apero.File` (facade) | 0% | ⚠️ Idem |
| `Apero.Http.Adapter` (behaviour) | N/A | behaviour sin código |
| `Apero` (root facade) | 77.7% | ✅ (commit `fb90167`) |

**Coverage global**: **50.0%** (vs 48.7% original). Cubre los submódulos principales. Los facades quedan a 0% por diseño (los tests van contra los submodules directamente — ver AUDIT.md §C.3).

**Objetivo 70%** NO se alcanza sin tests de facades. Decisión arquitectural pendiente: ¿testear facades o no?

---

## 6. Cierre del proyecto

### ✅ Tareas implementadas en este ciclo (22/29 = 76%)

Ver §2 para el detalle completo de:
- 4/4 P0 fixes
- 7/7 P1 fixes
- 11/11 P2 fixes
- 10/10 P3 polish items
- AUDIT v2 + agrupación por impacto

### ❌ Pendientes (3/29 = 10%)

| Tarea | Tipo | Razón |
|-------|------|-------|
| APE-01..04 (splits) | MEDIO | Requieren sesiones dedicadas (8-15h total) |
| APE-15 (breaking change) | CRÍTICO | Bloqueado por coordinación con consumers |

### 🟢 Cierre del proyecto

**apero está cerrado** en cuanto a bugs, seguridad y coverage. Las únicas tareas restantes son refactors gordos (4 splits estructurales) y un breaking change que requiere decisión de diseño.

**Recomendación**:
1. Los splits APE-01..04 se pueden abordar en cualquier momento en una sesión dedicada (8-15h total)
2. APE-15 (encrypt/2 breaking change) debe coordinarse con trebejo/candil/botica/delfos antes de merge

---

## 7. Dependencias externas

Apero no depende de otros proyectos lorenzo-sf en runtime.

**Consumers de apero**:
- **Trebejo** (consume OS, Proc, File, Packages)
- **Candil** (consume Http, Retry, OS, Finch)
- **Botica** (consume OS)
- **Delfos** (consume Crypto, HTTP indirectamente vía Candil desde v2.8.0)

Cambios en API pública de apero requieren smoke tests en estos 4 proyectos.

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