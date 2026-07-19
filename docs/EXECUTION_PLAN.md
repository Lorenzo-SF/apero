# Apero v3.1.0 — Execution Plan

> Generado desde `AUDIT.md` (2026-07-19). Plan detallado para ejecución autónoma.

---

## 1. Resumen

| Severidad | Cantidad | Esfuerzo estimado |
|-----------|----------|-------------------|
| 🔴 P0 | 4 | ~3h |
| 🟠 P1 | 7 | ~7h 30min |
| 🟡 P2 | 11 | ~6h 45min |
| 🟢 P3 | 10 | ~3h 30min |
| **Total** | **32** | **~20h 45min** |

---

## 2. Orden de ejecución recomendado

```
FASE 1 (P0):   APE-01 → APE-02 → APE-03 → APE-04
                    ↓
FASE 2 (P1):   APE-05  APE-06 → APE-18  APE-07  APE-08  APE-09*  APE-10 → APE-13  APE-11
                    ↓         ↓
FASE 3 (P2):   APE-12  APE-14  APE-15  APE-16  APE-17  APE-19  APE-20  APE-21  APE-22
                    ↓
FASE 4 (P3):   APE-23→APE-32 (orden arbitrario, sin dependencias)
```

\* APE-09 depende de APE-01 (el fix del encoding debe estar hecho antes de testear el adapter).
APE-18 depende de APE-06 (ambos tocan `checksum_many` — arreglar O(n²) primero, luego el `:error` key).
APE-13 recomendado después de APE-10 (mismo fichero `cache/crypto.ex`).

---

## 3. Fases

### Fase 1: Críticos (P0)

---

### APE-01: Reemplazar `Jason.encode!` por `Jason.encode` con manejo de error
- **Hallazgo**: P0-1 — `Jason.encode!` crashes on non-encodable body
- **Severidad**: 🔴 P0
- **Ficheros**: `lib/apero/http/adapter/finch.ex`
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Escribir test que reproduzca el crash: pasar un struct sin `Jason.Encoder` como body a `request/1`, verificar que devuelve `{:error, %Apero.Http.Error{}}` en lugar de levantar `Jason.EncodeError`
  2. Extraer `encode_body/1` con dos cláusulas: `when is_map(body) or is_list(body)` → `Jason.encode(body)`, else → `{:ok, body}`
  3. Modificar `to_finch_request/1` para usar `with {:ok, finch_body} <- encode_body(body)` y devolver `{:ok, finch_request}` o `{:error, _}`
  4. Actualizar `request/1` para handlear `{:error, _}` de `to_finch_request/1`
  5. Actualizar `stream/4` para handlear `{:error, _}` de `to_finch_request/1`
  6. Verificar que el test de reproducción ahora pasa
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Cambia el contrato interno de `to_finch_request/1` (antes devolvía un `Finch.Request.t()`, ahora `{:ok, req} | {:error, _}`). Verificar que ningún otro caller usa `to_finch_request/1` directamente.

---

### APE-02: Eliminar `Process.sleep(50)` en Finch startup
- **Hallazgo**: P0-2 — Hard-coded `Process.sleep(50)` race condition
- **Severidad**: 🔴 P0
- **Ficheros**: `lib/apero/http/finch.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Eliminar `Process.sleep(50)` — si `Finch.start_link/2` devuelve `{:ok, pid}`, Finch ya está listo
  2. Verificar que no hay código que asuma el sleep (e.g., tests que dependan del delay)
  3. Ejecutar tests del módulo Finch: buscan `:noproc` o problemas de race
  4. Opcional: añadir espera con `Process.monitor` + `receive` si se descubre que Finch no está 100% listo al retornar
- **Verificación**: `mix test --cover` + test de integración que haga requests inmediatamente después de start_link
- **Riesgos**: Si Finch tiene un bug y no está realmente listo al retornar `{:ok, pid}`, podrían aparecer `:noproc`. Monitorear en staging.

---

### APE-03: Cambiar `:error` a `{:error, term()}` en `decrypt_ctr/3`
- **Hallazgo**: P0-3 — `decrypt_ctr/3` returns bare atom `:error` instead of tuple
- **Severidad**: 🔴 P0
- **Ficheros**: `lib/apero/crypto/cipher.ex`, `lib/apero/crypto.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En `lib/apero/crypto/cipher.ex:108-116`, cambiar `rescue _ -> :error` por `rescue e -> {:error, e}`
  2. Actualizar `@spec decrypt_ctr/3` de `:: {:ok, binary()} | :error` a `:: {:ok, binary()} | {:error, term()}`
  3. En `lib/apero/crypto.ex:116-118`, actualizar el wrapper deprecated si tiene el mismo patrón
  4. Buscar callers de `decrypt_ctr/3` en el codebase y actualizar pattern matches
  5. Escribir test que verifique que un error de decrypt devuelve `{:error, _}`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Cambio rompente para consumidores que matcheen `:error`. Verificar proyectos que usan apero (alaja, arrea, etc.).

---

### APE-04: Eliminar auto-generación de key en `encrypt/2`
- **Hallazgo**: P0-4 — `encrypt/2` auto-generates key without returning it
- **Severidad**: 🔴 P0
- **Ficheros**: `lib/apero/crypto/cipher.ex`
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Cambiar `def encrypt(plaintext, key \\ nil)` a `def encrypt(plaintext, key)` (quitar default)
  2. Eliminar la lógica `key = key || generate_key()` dentro del cuerpo
  3. Actualizar `@spec` para requerir key explícita: `@spec encrypt(binary(), binary()) :: {:ok, binary()} | {:error, term()}`
  4. Añadir guard clause: `when is_binary(plaintext) and byte_size(key) == 32`
  5. Actualizar todos los callers en tests y en el proyecto para pasar key explícita
  6. Escribir test que verifique que `encrypt/1` (sin key) ya no compila o da error
- **Verificación**: `mix test --cover` + `mix credo --all` + `mix compile --warnings-as-errors`
- **Riesgos**: Breaking change. Cualquier código que llame `Apero.Crypto.Cipher.encrypt/1` (sin key) dejará de compilar. Verificar proyectos consumidores.

---

### Fase 2: Alta prioridad (P1)

---

### APE-05: Eliminar `String.to_atom` fallback en `key_to_atom/1`
- **Hallazgo**: P1-1 — Dynamic atom creation via `String.to_atom` fallback
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/apero/conf.ex`
- **Esfuerzo**: 2h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Analizar cómo se usa `key_to_atom/1`: ¿de dónde vienen las keys? ¿pueden ser arbitrarias?
  2. Opción A (segura): eliminar el fallback, permitir solo `String.to_existing_atom/1`, documentar que las keys deben ser átomos conocidos
  3. Opción B (migración): aceptar string keys en `deep_get`/`deep_set` además de átomos
  4. Opción C (validación): añadir regex que valide el input antes de `String.to_atom` (e.g., solo letras + guiones bajos)
  5. Implementar la opción elegida
  6. Actualizar tests de `Apero.Conf` que dependan del comportamiento actual
  7. Eliminar `# credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom`
- **Verificación**: `mix test --cover` + `mix credo --all` + `mix dialyzer`
- **Riesgos**: Si se elige la opción A, código que pase keys dinámicas a `deep_get`/`deep_set` dejará de funcionar. Migrar gradualmente.

---

### APE-06: Optimizar `checksum_many` de O(n²) a O(n)
- **Hallazgo**: P1-2 — `checksum_many` O(n²) result reconstruction
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/apero/file/io.ex`
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En `checksum_many/2`, cambiar `Task.async_stream` para que el closure retorne `{path, result}` en lugar de `{idx, result}`
  2. Eliminar `Enum.with_index/1`
  3. Reemplazar `Enum.reduce` que usa `Enum.at(paths, idx)` por acumulación directa: `Map.put(acc, path, result)`
  4. Verificar que el map resultante tiene las mismas keys (paths) que antes
  5. Añadir benchmark o test con lista grande para verificar mejora
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: El formato del map resultante cambia ligeramente si había paths duplicados (antes el último `Enum.at` ganaba, ahora el último task en completarse gana). En la práctica paths son únicos.

---

### APE-07: Mejorar detección de WSL
- **Hallazgo**: P1-3 — WSL detection via fragile PATH heuristic
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/apero/os.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Reemplazar `String.contains?(System.get_env("PATH", ""), "WSL")` por detección vía `/proc/sys/fs/binfmt_misc/WSLInterop` o `/proc/version`
  2. Implementar: `File.exists?("/proc/sys/fs/binfmt_misc/WSLInterop") or (File.exists?("/proc/version") and String.contains?(File.read!("/proc/version"), "microsoft"))`
  3. Mantener el guard `type() == :linux`
  4. Escribir test que verifique que en Linux sin esos ficheros devuelve `false`
  5. Mockear `File.exists?`/`File.read!` para simular WSL y no-WSL
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: En WSL2 la ruta del binfmt_misc puede diferir. Verificar en WSL2 real si es posible.

---

### APE-08: Tests para retry no-blocking
- **Hallazgo**: P1-4 — Non-blocking retry path completely untested
- **Severidad**: 🟠 P1
- **Ficheros**: `test/apero/retry_test.exs` (nuevos tests en fichero existente o nuevo)
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Escribir test para `schedule_next/7`: llamarlo y verificar con `assert_receive` que se envía un mensaje
  2. Escribir test para `handle_message/1`: mockear `should_retry?/1` para que devuelva `true`/`false` y verificar valores de retorno
  3. Escribir test de integración: configurar un retry no-blocking que falle N veces y luego tenga éxito, verificar que se llama al callback final
  4. Verificar cobertura en `Apero.Retry` sube del 65.7%
- **Verificación**: `mix test --cover` (verificar cobertura en `lib/apero/retry.ex` ≥ 90%) + `mix credo --all`
- **Riesgos**: `schedule_next` usa `Process.send_after` — los tests deben usar `assert_receive` con timeout suficiente.

---

### APE-09: Tests para Finch HTTP adapter
- **Hallazgo**: P1-5 — Zero test coverage on entire Finch HTTP adapter
- **Severidad**: 🟠 P1
- **Ficheros**: `test/apero/http/adapter/finch_test.exs` (nuevo)
- **Esfuerzo**: 2h
- **Dependencias**: APE-01 (el fix de encoding debe estar hecho)
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Añadir `bypass` como dependencia dev/test en `mix.exs` (o usar `Finch.start_link` + servidor HTTP local)
  2. Escribir test para `request/1` con respuesta JSON: crear un endpoint con Bypass, enviar request, verificar `{:ok, %Apero.Http.Response{body: parsed_json}}`
  3. Escribir test para `request/1` con respuesta no-JSON (text/plain)
  4. Escribir test para `request/1` con error de conexión (Bypass no iniciado)
  5. Escribir test para `request/1` con body no serializable → `{:error, _}` (verifica APE-01)
  6. Escribir test para `stream/4` con respuesta chunked
- **Verificación**: `mix test --cover` (verificar cobertura en `Apero.Http.Adapter.Finch` ≥ 80%) + `mix credo --all`
- **Riesgos**: Tests de integración HTTP requieren que el proceso Bypass esté vivo. Usar `setup` con `Bypass.open/0` y `on_exit`. Pueden ser lentos.

---

### APE-10: Añadir `@spec` a `Apero.Cache.Crypto`
- **Hallazgo**: P1-6 — No `@spec` on `Apero.Cache.Crypto` public functions
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/apero/cache/crypto.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Añadir `@spec sha256(binary()) :: binary()` antes de `def sha256/1`
  2. Añadir `@spec sha512(binary()) :: binary()` antes de `def sha512/1`
  3. Añadir `@spec md5(binary()) :: binary()` antes de `def md5/1`
  4. Verificar con `mix dialyzer` que no hay warnings nuevos
- **Verificación**: `mix dialyzer` + `mix test --cover` + `mix credo --all`
- **Riesgos**: Ninguno. Solo añade anotaciones.

---

### APE-11: Manejo de error en `mtime/1` con `DateTime.from_unix/1`
- **Hallazgo**: P1-7 — `mtime/1` uses `DateTime.from_unix!/1` without error handling
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/apero/file/path.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En `lib/apero/file/path.ex:136`, reemplazar `ts |> DateTime.from_unix!() |> DateTime.to_naive()` con `case DateTime.from_unix(ts) do {:ok, dt} -> {:ok, DateTime.to_naive(dt)}; {:error, reason} -> {:error, reason} end`
  2. Actualizar `@spec mtime/1` si necesita reflejar el `{:error, _}` return
  3. Escribir test con timestamp inválido (e.g., negativo) que verifique `{:error, _}`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Callers que esperaban `{:ok, dt}` incondicionalmente pueden necesitar handlear error ahora.

---

### Fase 3: Media (P2)

---

### APE-12: Añadir catch-all clause a `method_builder/1`
- **Hallazgo**: P2-1 — `method_builder/1` has no catch-all clause
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/http.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Añadir `defp method_builder(other), do: raise ArgumentError, "unsupported HTTP method: #{inspect(other)}"` al final de las cláusulas
  2. Escribir test que llame con `:head` y verifique `ArgumentError`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Ninguno. Es una cláusula de seguridad.

---

### APE-13: Prevenir TOCTOU race en cache ETS lookup
- **Hallazgo**: P2-2 — TOCTOU race in Crypto cache ETS lookup
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/cache/crypto.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna (recomendado después de APE-10 por mismo fichero)
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Reemplazar el patrón `case :ets.lookup(...) do [] -> value = compute_fun.(); :ets.insert(...) end` con `:ets.insert_new/2`
  2. Implementar: `:ets.insert_new(@table, {key, value}) || :ets.lookup_element(@table, key, 2)`
  3. Escribir test concurrente: lanzar N procesos que computen el mismo hash, verificar que solo uno computa (mockear compute_fun con un contador)
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: `:ets.insert_new/2` retorna `false` si la key ya existe. Asegurar que el valor existente se retorna correctamente.

---

### APE-14: Cache adapter resolution para pids no-ETS
- **Hallazgo**: P2-3 — Cache adapter resolution fails on pid for non-ETS caches
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/cache.ex`
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Crear un mecanismo de registro: ETS auxiliar o Process Dictionary que mapee pid → adapter module
  2. En `start_link/2`, registrar el adapter asociado al pid del cache process
  3. Modificar `adapter/1` para consultar el registro cuando recibe un pid
  4. Añadir `@impl true` en los adapters para que se registren automáticamente
  5. Escribir test que cree un cache con pid y verifique que se usa el adapter correcto
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Si un proceso muere, la entrada en el registro queda huérfana. Usar `Process.monitor` para limpiar.

---

### APE-15: Reducir mínimo de sweep timer
- **Hallazgo**: P2-4 — Sweep timer minimum 60s limits short TTLs
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/cache/ets.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Cambiar `max(ttl * 1000, 60_000)` a `max(ttl * 1000, 10_000)` en `init/1` y `put/4`
  2. O convertir en opción configurable: `opts[:min_sweep_interval] || 10_000`
  3. Actualizar documentación del módulo
  4. Escribir test que verifique TTLs cortos se barren antes de 60s
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Sweep más frecuente = más CPU. Para caches con muchos entries, 10s puede ser agresivo. Mantener configurable.

---

### APE-16: Fallback copy+delete en `atomic_write` cuando `rename` falla con EXDEV
- **Hallazgo**: P2-5 — `atomic_write` silently ignores `:exdev` on some OTP versions
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/file/io.ex`
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Identificar el punto donde `File.rename` puede fallar
  2. Añadir lógica de fallback: si `rename` falla con `:exdev`, hacer `File.copy!` + `File.rm!` del temporal
  3. Mantener el cleanup del temp file en caso de error general
  4. Escribir test que fuerce EXDEV (e.g., crear temp en otro filesystem simulado o mockear `File.rename`)
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: `File.copy` + `File.rm` no es atómico. Si el proceso muere entre copy y rm, el temp file queda. Documentar edge case.

---

### APE-17: Implementar `generate_tree` jerárquico
- **Hallazgo**: P2-6 — `generate_tree/1` does not build a hierarchy
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/file/tree.ex`
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Reescribir `generate_tree/1` para agrupar paths por directorio
  2. Implementar construcción recursiva de árbol: dividir paths por `/`, agrupar por primer segmento
  3. Mantener el formato de salida actual (conectores `├─`, `└─`)
  4. Escribir test con `["a/b", "a/c", "d/e/f"]` que verifique jerarquía correcta
  5. Actualizar documentación/docstring
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Cambia el formato de salida para paths con subdirectorios. Consumidores que parseen el output pueden romperse.

---

### APE-18: Reemplazar key `:error` con path en `checksum_many` task exit
- **Hallazgo**: P2-7 — `checksum_many` returns `:error` key on task exit
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/file/io.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: APE-06 (toca el mismo bloque de código)
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En la cláusula `{:exit, reason}, acc`, cambiar `Map.put(acc, :error, reason)` por `acc` (omitir) o usar `Map.put(acc, path, {:exit, reason})` si el path está disponible
  2. Si el path no está disponible en el exit (el task crasheó antes de emitir resultado), documentar que ese path no aparece en el map resultante
  3. Actualizar tests que dependan de la key `:error`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Consumidores que busquen `result[:error]` dejarán de funcionar.

---

### APE-19: Propagar error de Finch startup en `do_start_link`
- **Hallazgo**: P2-8 — `Finch.ensure_started/0` silences all startup errors
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/http/finch.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna (mismo fichero que APE-02 pero independiente)
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En `do_start_link/0`, cambiar el match `{:error, _reason} -> :ok` a que registre el error con `Logger.error` o retorne `{:error, reason}`
  2. Decidir política: ¿el supervisor debe reiniciar? ¿o es fatal?
  3. Escribir test que fuerce un error de configuración de Finch y verifique que no se silencia
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Si Finch falla al start, puede detener el supervisor. Asegurar que el error es claro para debugging.

---

### APE-20: Simplificar `os_pid/0`
- **Hallazgo**: P2-9 — `os_pid/0` uses roundabout conversion
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/proc.ex`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Cambiar `:os.getpid() |> List.to_string() |> String.to_integer()` a `:os.getpid() |> List.to_integer()`
  2. Verificar que el resultado es el mismo tipo y rango
  3. Ejecutar tests de `Apero.Proc`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: `List.to_integer/1` espera lista de dígitos. `:os.getpid/0` siempre retorna lista de dígitos en OTP. Seguro.

---

### APE-21: Validar que `Watcher` dirs sea no-vacío
- **Hallazgo**: P2-10 — No validation that `Watcher` dirs is non-empty
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/file/watcher.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Después de `dirs = Keyword.fetch!(opts, :dirs)`, añadir guard: `if dirs == [], do: raise ArgumentError, "dirs must be a non-empty list"`
  2. Escribir test que llame `start_link/1` con `dirs: []` y verifique `ArgumentError`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Ninguno. Validación temprana.

---

### APE-22: Rechazar tipos de schema desconocidos en `type_matches?`
- **Hallazgo**: P2-11 — `agent_get` returns `true` on invalid schema types
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/apero/conf.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En `type_matches?/2`, cambiar el catch-all `defp type_matches?(_value, _), do: true` a `defp type_matches?(_value, unknown_type), do: false`
  2. Añadir log opcional: `Logger.warning("unknown schema type: #{inspect(unknown_type)}")`
  3. Escribir test con schema type `:date` que verifique `{:error, _}`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Si hay tipos conocidos sin cláusula explícita, empezarán a fallar. Verificar que todos los tipos usados tienen cláusula.

---

### Fase 4: Baja (P3)

---

### APE-23: Corregir doc de `generate_tree`
- **Hallazgo**: P3-1 — `generate_tree` doc example inconsistent with implementation
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/file.ex`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Actualizar `@doc` de `generate_tree/1` para clarificar que el output es plano (sin jerarquía de directorios) y el ejemplo con `["a/b"]` produce `└─ b`
- **Verificación**: `mix test` (doctests)
- **Riesgos**: Ninguno.

---

### APE-24: Extraer default TTL a módulo attribute
- **Hallazgo**: P3-2 — Hard-coded TTL default 3600 in multiple places
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/cache/ets.ex`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Definir `@default_ttl 3600` como module attribute
  2. Reemplazar literales `3600` en `init/1` y `put/4` por `@default_ttl`
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Ninguno.

---

### APE-25: Documentar que `stream_finalize/1` siempre retorna `<<>>`
- **Hallazgo**: P3-3 — `stream_finalize/1` returns `binary()` from state update
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/crypto/cipher.ex`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Actualizar `@doc` de `stream_finalize/1` para indicar que el valor de retorno siempre es `<<>>`
- **Verificación**: `mix test`
- **Riesgos**: Ninguno.

---

### APE-26: Devolver byte count real en `copy_many`
- **Hallazgo**: P3-4 — `copy_many` returns `{:ok, 0}` instead of actual byte count
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/file/io.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Reemplazar `{:ok, 0}` con `{:ok, bytes}` capturando el valor de `File.copy`
  2. Actualizar `@spec` si necesario
  3. Escribir test que copie un fichero y verifique el byte count
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Consumidores que ignoren el byte count (la mayoría) no se ven afectados.

---

### APE-27: Corregir `:apt` en Packages a `"apt"` en lugar de `"apt-get"`
- **Hallazgo**: P3-5 — `Packages` has `:apt` and `:apt_get` both mapping to `"apt-get"`
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/packages.ex`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Cambiar `:apt` → `"apt"` (en lugar de `"apt-get"`)
  2. Verificar que `:apt_get` sigue → `"apt-get"`
  3. Actualizar tests si verifican el nombre del binario
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Consumidores que llamen a Packages con `:apt` esperando `"apt-get"` se rompen. Esto es una corrección de bug, no breaking change semántico.

---

### APE-28: Mejorar distribución de jitter en retry
- **Hallazgo**: P3-6 — jitter distribution is rolled, not random in full range
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/retry.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Cambiar `jitter_range = round(exponential * 0.3)` por full-jitter: valor aleatorio en `[0, exponential)`
  2. Usar `:rand.uniform() * exponential` para distribución uniforme
  3. Actualizar tests que verifiquen jitter específico
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Cambia la distribución, puede afectar patrones de backoff existentes (mejor distribución, menos picos).

---

### APE-29: Añadir `:pool_timeout` en stream options
- **Hallazgo**: P3-7 — No `:pool_timeout` in stream options
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/http/adapter/finch.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En la rama de streaming de `to_finch_opts`, extraer `pool_timeout` de `opts` igual que se hace en la rama no-streaming
  2. Añadirlo al mapa de opciones de Finch para la conexión stream
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Bajo. Consistencia entre ramas.

---

### APE-30: Clarificar documentación de `Env.load/1` vs `Env.read/1`
- **Hallazgo**: P3-8 — `loader` doc says "mutates global OS environment" but `read/1` doesn't
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/env.ex`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Mover la advertencia de mutación a `@doc` de `load/1` solamente
  2. Añadir nota en `read/1` de que NO muta el entorno
- **Verificación**: `mix test`
- **Riesgos**: Ninguno.

---

### APE-31: Añadir logging a `with_lock` en fallos no-E EXIST
- **Hallazgo**: P3-9 — `with_lock` catches all `File.open` errors except `:eexist`
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/file/io.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Añadir `Logger.warning("with_lock failed for #{path}: #{inspect(reason)}")` en el branch de error no-EEXIST
  2. Añadir `require Logger` al módulo
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Logging excesivo si hay contienda alta de locks. Considerar rate-limiting.

---

### APE-32: Retornar DateTime UTC en `mtime/1` en lugar de NaiveDateTime
- **Hallazgo**: P3-10 — `mtime/1` returns NaiveDateTime, losing timezone info
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/apero/file/path.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Cambiar `DateTime.to_naive(dt)` por `dt` (mantener DateTime)
  2. Actualizar `@spec mtime/1` de `:: {:ok, NaiveDateTime.t()}` a `:: {:ok, DateTime.t()}`
  3. Actualizar callers que esperen NaiveDateTime
  4. Añadir `DateTime.to_naive()` en los callers si es necesario
- **Verificación**: `mix test --cover` + `mix credo --all`
- **Riesgos**: Breaking change en tipo de retorno. Consumidores que matcheen `%NaiveDateTime{}` se rompen.

---

## 4. Dependencias externas

| Tarea | Dependencia externa | Proyecto |
|-------|---------------------|----------|
| APE-09 | `bypass` para tests HTTP (añadir a `mix.exs` como dep dev/test) | Mix |
| APE-03, APE-04 | Verificar proyectos consumidores (alaja, arrea, trebejo, botica, delfos) si se cambia interfaz pública | Varios |
| Todas | Tener `mix deps.get` y `mix deps.compile` exitosos | — |

Apero no depende de ningún proyecto Lorenzo-SF. Todas las dependencias son externas (hex.pm).

---

## 5. Riesgos globales

1. **Breaking changes en interfaz pública**: APE-03 (cambio de `:error` a `{:error, _}`), APE-04 (eliminar default key), APE-32 (cambio de NaiveDateTime a DateTime). Requieren verificar proyectos consumidores.
2. **Tests de integración HTTP**: APE-09 usa Bypass — frágil en CI si hay problemas de puertos. Usar puerto 0 para asignación dinámica.
3. **Cobertura actual 44.6%**: Muchas tareas (especialmente P2/P3) tocan módulos con 0% coverage. Es difícil verificar regresión donde no hay tests. Considerar añadir tests básicos primero.
4. **Cambios concurrentes en mismo fichero**: APE-06 + APE-18 (io.ex), APE-02 + APE-19 (finch.ex), APE-10 + APE-13 (cache/crypto.ex). Planificar secuencia para evitar conflictos de merge.
5. **`FileSystem` watcher**: APE-21 modifica watcher.ex. Los tests de watcher son difíciles de hacer deterministas. Validar manualmente.

---

## 6. Comandos de verificación

```bash
# Después de cada tarea:
mix test --cover                              # Tests + cobertura
mix credo --all                               # Estilo (0 violaciones)
mix format --check-formatted                  # Formato
mix compile --warnings-as-errors              # Compilación limpia
mix dialyzer                                  # Tipos (opcional por lentitud)

# Full QA (alias del proyecto):
mix qa                                        # format + compile + dialyzer + test --cover
mix lint                                      # igual + credo --strict
```
