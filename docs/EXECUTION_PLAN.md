# Apero v2.3.0 — Plan de Ejecución

> **Última actualización**: 2026-07-21
> **Auditoría complementaria**: revisión tras batch de calidad (2026-07-21)
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
| 🟠 P1 (estimado) | 5 | 0 | 5 |
| 🟡 P2 (estimado) | 8 | 0 | 8 |
| **Refactors estructurales** | — | — | 3 |
| **Coverage gaps** | — | — | 4 |
| **Total tareas** | **13 + 7** | **0** | **20** |

**Esfuerzo restante estimado**: ~25h (auditoría completa + refactors + tests).

**Nota importante**: este plan es **tentativo** — las tareas son inferidas de inspección rápida, no de un audit profundo. Antes de empezar, ejecutar un audit formal.

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