# Apero v3.1.0 — Code Quality Audit

> **Audit date:** 2026-07-19
> **Project:** `apero` — Foundation utility library for Lorenzo-SF ecosystem
> **Lines of code:** 3,229 (lib/) + 1,344 (test/) = 4,573 total
> **Test suites:** 10 test files, 161 tests

---

## Summary

| Metric | Value |
|---|---|
| **Test count** | 161 passing, 0 failing |
| **Test coverage** | **44.6%** (TOTAL) |
| **Threshold** | 80% (configured in `mix.exs`) |
| **Credo violations** | **0** (clean) |
| **Modules** | 37 (lib/) |
| **Modules ≥ 80% coverage** | 12 (32%) |
| **Modules with 0% coverage** | 15 (41%) |
| **P0 (🔴 Critical)** | 4 |
| **P1 (🟠 High)** | 7 |
| **P2 (🟡 Medium)** | 11 |
| **P3 (🟢 Low)** | 10 |

---

## 🔴 P0 — Critical findings

### P0-1 — `Jason.encode!` crashes on non-encodable body (`http/adapter/finch.ex:55`)

**Problem:** `to_finch_request/1` calls `Jason.encode!(body)` for map/list bodies. If `body` contains a struct without a `Jason.Encoder` implementation, or any non-encodable term, `Jason.encode!` raises a `Jason.EncodeError`. This is uncaught and crashes the calling process.

```elixir
# lib/apero/http/adapter/finch.ex:55
finch_body = if is_map(body) or is_list(body), do: Jason.encode!(body), else: body
```

**Fix:** Replace with `Jason.encode/1` and return `{:error, Apero.Http.Error.t()}`:

```elixir
defp to_finch_request(%Apero.Http.Request{method: method, url: url, headers: headers, body: body}) do
  method = String.upcase(Atom.to_string(method))
  with {:ok, finch_body} <- encode_body(body) do
    Finch.build(method, url, headers, finch_body)
  end
end

defp encode_body(body) when is_map(body) or is_list(body),
  do: Jason.encode(body)
defp encode_body(body), do: {:ok, body}
```

Then update `request/1` and `stream/4` to handle the `{:error, _}` from `to_finch_request`.

---

### P0-2 — Hard-coded `Process.sleep(50)` race condition (`http/finch.ex:39`)

**Problem:** `do_start_link/0` uses `Process.sleep(50)` to wait for the Finch process to register. There is no guarantee that 50ms is sufficient under load. This is a race — Finch may not be ready when the first request arrives, causing `:noproc` errors.

```elixir
# lib/apero/http/finch.ex:37-39
case Finch.start_link(name: @finch_name, pools: pools) do
  {:ok, _pid} ->
    Process.sleep(50)  # ← race
```

**Fix:** Replace the sleep with process monitoring using `Process.monitor` or `Process.whereis` in a retry loop, or simply remove it — if Finch returns `{:ok, pid}`, it is ready.

---

### P0-3 — `decrypt_ctr/3` returns bare atom `:error` instead of tuple (`crypto/cipher.ex:108-116`)

**Problem:** `decrypt_ctr/3` returns `:error` (bare atom) on failure, while every other API function in Apero returns `{:error, term()}`. This silently breaks consumers that pattern-match on `{:error, _}`.

```elixir
# lib/apero/crypto/cipher.ex:108-116
@spec decrypt_ctr(binary(), binary(), binary()) :: {:ok, binary()} | :error
def decrypt_ctr(ciphertext, key, iv) ...
  rescue
    _ -> :error  # ← bare atom, inconsistent with rest of API
```

**Fix:** Change return to `{:error, term()}`:

```elixir
rescue
  e -> {:error, e}
```

Also fix the `@spec` and the deprecated wrapper in `lib/apero/crypto.ex:116-118`.

---

### P0-4 — `encrypt/2` auto-generates key without returning it (`crypto/cipher.ex:22-27`)

**Problem:** `encrypt/2` accepts an optional key (`key \\ nil`). When `key` is nil, it generates a random 32-byte key using `generate_key/0` but **never returns it**. The caller receives `{:ok, ciphertext}` with no way to know what key was used, making the data permanently unrecoverable.

```elixir
# lib/apero/crypto/cipher.ex:22-27
def encrypt(plaintext, key \\ nil) when is_binary(plaintext) do
  key = key || generate_key()  # ← key discarded after encryption
  ...
  {:ok, result}                 # ← no key returned
end
```

**Fix:** Remove the auto-generation fallback. Require the key to be explicitly provided:

```elixir
@spec encrypt(binary(), binary()) :: {:ok, binary()} | {:error, term()}
def encrypt(plaintext, key) when is_binary(plaintext) and byte_size(key) == 32 do
  ...
end
```

Or return `{:ok, {ciphertext, key}}` (breaking change, but the current behavior is a trap).

---

## 🟠 P1 — High findings

### P1-1 — Dynamic atom creation via `String.to_atom` fallback (`conf.ex:114-120`)

**Problem:** `key_to_atom/1` first tries `String.to_existing_atom/1`, then falls back to `String.to_atom/1` (which creates atoms dynamically). Atoms are never garbage collected, so an attacker controlling config keys can exhaust the BEAM atom table (DoS). Credo's `UnsafeToAtom` check is explicitly disabled on the fallback line.

```elixir
# lib/apero/conf.ex:114-120
defp key_to_atom(key) do
  String.to_existing_atom(key)
rescue
  ArgumentError ->
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom(key)  # ← unsafe
end
```

**Fix:** Accept string keys throughout `deep_get`/`deep_set`, or validate the input with a regex before calling `String.to_atom`. Better yet, use `String.to_existing_atom` exclusively and document that all config keys must be known atoms.

---

### P1-2 — `checksum_many` O(n²) result reconstruction (`file/io.ex:64-66`)

**Problem:** `checksum_many` uses `Enum.with_index` + `Enum.at(paths, idx)` to map results back to paths. `Enum.at` on a list is O(n), making the entire function O(n²). For 10,000 files this is 50M operations.

```elixir
# lib/apero/file/io.ex:64-66
{:ok, {idx, {:ok, result}}}, acc ->
  Map.put(acc, Enum.at(paths, idx), {:ok, result})  # ← O(n²)
```

**Fix:** Pass the path directly through the task closure instead of the index:

```elixir
paths
|> Task.async_stream(
  fn path -> {path, checksum(path, algo)} end,
  ...
)
|> Enum.reduce(%{}, fn
  {:ok, {path, {:ok, result}}}, acc -> Map.put(acc, path, {:ok, result})
  {:ok, {path, {:error, reason}}}, acc -> Map.put(acc, path, {:error, reason})
  {:exit, reason}, acc -> Map.put(acc, :error, reason)
end)
```

---

### P1-3 — WSL detection via fragile PATH heuristic (`os.ex:61`)

**Problem:** WSL detection checks `String.contains?(System.get_env("PATH", ""), "WSL")`. This produces false positives on any system where a PATH component happens to contain the substring "WSL" (e.g., `/opt/wslinux-tools`).

```elixir
# lib/apero/os.ex:61
String.contains?(System.get_env("PATH", ""), "WSL")
```

**Fix:** Check for `/proc/sys/fs/binfmt_misc/WSLInterop` (the reliable method) or check `/proc/version` for "microsoft":

```elixir
def wsl? do
  type() == :linux and
    (File.exists?("/proc/sys/fs/binfmt_misc/WSLInterop") or
     File.exists?("/proc/version") && File.read!("/proc/version") |> String.contains?("microsoft"))
end
```

---

### P1-4 — Non-blocking retry path completely untested (`retry.ex:63-114`)

**Problem:** `schedule_next/7` and `handle_message/1` (the non-blocking/scheduled retry API) have zero test coverage. The only retry tests exercise the blocking `with/2` path. Bugs in the non-blocking path will only be discovered at runtime.

**Fix:** Write tests that:
1. Call `schedule_next/7` and verify a message is sent via `assert_receive`
2. Call `handle_message/1` with various `should_retry?` results and verify return values

---

### P1-5 — Zero test coverage on entire Finch HTTP adapter (`http/adapter/finch.ex`)

**Problem:** `Apero.Http.Adapter.Finch` has 0% coverage (28 relevant lines, 0 executed). The `request/1`, `stream/4`, JSON encoding/decoding, content-type detection, and Finch option building are all untested.

**Fix:** Implement adapter tests using `Bypass` or a local HTTP server. At minimum:
- Test `request/1` with JSON and non-JSON responses
- Test `request/1` with connection errors
- Test `stream/4` with a streaming response (chunked transfer)

---

### P1-6 — No `@spec` on `Apero.Cache.Crypto` public functions (`cache/crypto.ex:29-46`)

**Problem:** The three public functions (`sha256/1`, `sha512/1`, `md5/1`) in `Apero.Cache.Crypto` have no `@spec` annotations, even though they are called from the deprecated facade (`Apero.Crypto`). This means Dialyzer misses type errors in these signatures.

**Fix:** Add `@spec` annotations:

```elixir
@spec sha256(binary()) :: binary()
@spec sha512(binary()) :: binary()
@spec md5(binary()) :: binary()
```

---

### P1-7 — `mtime/1` uses `DateTime.from_unix!/1` without error handling (`file/path.ex:136`)

**Problem:** `mtime/1` calls `DateTime.from_unix!(ts)` with the POSIX timestamp. This will raise if the file's mtime is before Unix epoch (Jan 1 1970) or after year 10,000. While rare, `DateTime.from_unix!` can raise on extreme values or invalid timestamps.

```elixir
# lib/apero/file/path.ex:136
{:ok, ts |> DateTime.from_unix!() |> DateTime.to_naive()}
```

**Fix:** Use `DateTime.from_unix/1` and propagate the error:

```elixir
case DateTime.from_unix(ts) do
  {:ok, dt} -> {:ok, DateTime.to_naive(dt)}
  {:error, reason} -> {:error, reason}
end
```

---

## 🟡 P2 — Medium findings

### P2-1 — `method_builder/1` has no catch-all clause (`http.ex:159-164`)

If an unsupported method atom is passed (e.g., `:head`, `:options`), `method_builder/1` raises `FunctionClauseError`. Should return a descriptive error:

```elixir
defp method_builder(:get), do: Apero.Http.Method.Get
defp method_builder(:post), do: Apero.Http.Method.Post
...
defp method_builder(other), do: raise ArgumentError, "unsupported HTTP method: #{inspect(other)}"
```

---

### P2-2 — TOCTOU race in Crypto cache ETS lookup (`cache/crypto.ex:50-59`)

Between `:ets.lookup/2` returning `[]` and `:ets.insert/2`, another process may compute and insert the same hash. ETS set tables deduplicate by key (last write wins), so no corruption occurs, but the duplicate computation wastes CPU. A `:ets.insert_new/2` guard would prevent this:

```elixir
defp lookup_store(key, compute_fun) do
  case :ets.lookup(@table, key) do
    [{^key, value}] -> value
    [] ->
      value = compute_fun.()
      :ets.insert_new(@table, {key, value}) || :ets.lookup_element(@table, key, 2)
  end
end
```

---

### P2-3 — Cache adapter resolution fails on pid for non-ETS caches (`cache.ex:89`)

When the cache name is a pid, `adapter/1` always returns `Apero.Cache.ETS`, ignoring the registered adapter. This means the `Apero.Cache` facade cannot dispatch to Redis/Memcached adapters by pid.

```elixir
defp adapter(pid) when is_pid(pid), do: Apero.Cache.ETS  # ← hardcoded
```

**Fix:** Store a process dictionary or ETS mapping from pid → adapter module.

---

### P2-4 — Sweep timer minimum 60s limits short TTLs (`cache/ets.ex:25,84`)

The sweep interval is `max(ttl * 1000, 60_000)`. For a TTL of 10s, expired entries may linger for up to 60 seconds. This is a memory concern for high-throughput caches with short TTLs.

**Fix:** Reduce minimum sweep interval to `max(ttl * 1000, 10_000)` or make it configurable.

---

### P2-5 — `atomic_write` silently ignores `:exdev` on some OTP versions (`file/io.ex:18-26`)

While the temp file is created in the same directory (same filesystem as target), if the path involves FUSE mounts or symlinks across filesystems, `File.rename` may fail. The error is caught and the temp file is cleaned up, but the function returns an opaque `{:error, "atomic_write failed for ...: exdev"}` without falling back to copy+delete.

---

### P2-6 — `generate_tree/1` does not build a hierarchy (`file/tree.ex:11-23`)

`generate_tree` treats all paths as flat sorted items with connectors. For inputs like `["a/b", "a/c"]`, it produces:
```
├─ b
└─ c
```
Without showing the `a/` parent. This is misleading. A proper tree builder should group by directory.

---

### P2-7 — `checksum_many` returns `:error` key on task exit (`file/io.ex:72`)

On task exit, the map key is the atom `:error`, not a path. This is inconsistent — when a task crashes, callers can't determine which file caused the issue.

```elixir
{:exit, reason}, acc -> Map.put(acc, :error, reason)  # ← loses path context
```

**Fix:** Use a sentinel value or skip the entry in the map.

---

### P2-8 — `Finch.ensure_started/0` silences all startup errors (`http/finch.ex:45-46`)

If Finch fails to start (e.g., pool configuration error), `do_start_link` returns `:ok` regardless. The startup failure is hidden from the caller, who will only see connection errors later.

```elixir
{:error, _reason} -> :ok  # ← silent swallow
```

**Fix:** Log the error or raise on misconfiguration.

---

### P2-9 — `os_pid/0` uses roundabout conversion (`proc.ex:40`)

```elixir
def os_pid, do: :os.getpid() |> List.to_string() |> String.to_integer()
```
Could be simplified to:
```elixir
def os_pid, do: :os.getpid() |> List.to_integer()
```

---

### P2-10 — No validation that `Watcher` dirs is non-empty (`file/watcher.ex:31`)

`start_link/1` uses `Keyword.fetch!(opts, :dirs)` but passes an empty list through to `FileSystem.start_link`, which may crash with a confusing error. Should validate early:

```elixir
dirs = Keyword.fetch!(opts, :dirs)
if dirs == [], do: raise ArgumentError, "dirs must be a non-empty list"
```

---

### P2-11 — `agent_get` returns `true` on invalid schema types (`conf.ex:202`)

```elixir
defp type_matches?(_value, _), do: true  # ← catch-all accepts anything
```

If a schema specifies an unknown type (e.g., `:date`), validation silently passes. Should return `false` for unknown types.

---

## 🟢 P3 — Low findings

### P3-1 — `generate_tree` doc example inconsistent with implementation (`file.ex:273`)
Doc shows `Apero.File.generate_tree(["a"])` returning `"└─ a"`, but with only one item the connector should be `└─` (which is correct for last item). However, for `["a/b"]`, it returns `└─ b` (missing parent). Doc should clarify flat-output behavior.

### P3-2 — Hard-coded TTL default 3600 in multiple places (`cache/ets.ex:22,31`)
The default TTL is repeated in `init/1` and `put/4`. Should be a module attribute.

### P3-3 — `stream_finalize/1` returns `binary()` from state update (`crypto/cipher.ex:100-103`)
The function finalizes a streaming state which is already consumed. Return value is `<<>>` (empty binary) in practice. Should document that the return is always `<<>>`.

### P3-4 — `copy_many` returns `{:ok, 0}` instead of actual byte count (`file/io.ex:138`)
```elixir
{:ok, _bytes} <- File.copy(source, dest) do
  {:ok, 0}  # ← discards actual byte count
```

### P3-5 — `Packages` has `:apt` and `:apt_get` both mapping to `"apt-get"` (`packages.ex:96-97`)
This means duplicate entries in the detection map. `:apt` should map to `"apt"`.

### P3-6 — `retry.ex:135` jitter distribution is rolled, not random in full range
`jitter_range = round(exponential * 0.3)` adds `[0, exp*0.3)` uniform jitter. Standard full-jitter would be `[0, exp)`. Not a bug, but suboptimal for load balancing.

### P3-7 — No `:pool_timeout` in stream options (`http/adapter/finch.ex:84`)
`to_finch_opts` for non-streaming includes `pool_timeout`, but the stream path doesn't pass it through in the same way (it receives `opts` from caller but doesn't extract `pool_timeout`).

### P3-8 — `loader` doc says "mutates global OS environment" but `read/1` doesn't (`env.ex:22`)
The `@doc` warning is above `load/1` but `read/1` has no such warning, which is correct. However, both func have similar structure and a developer refactoring one could forget about the side-effect difference.

### P3-9 — `with_lock` catches all `File.open` errors except `:eexist` (`file/io.ex:150-164`)
Only `:eexist` triggers retry. Other errors (e.g., permission denied) immediately return `{:error, ...}`. Correct behavior, but no logging.

### P3-10 — `mtime/1` returns NaiveDateTime, losing timezone info (`file/path.ex:136`)
Using `DateTime.to_naive/1` discards timezone. File mtimes are typically UTC. Should return UTC `DateTime` instead.

---

## 📊 Coverage Detail

| Module | Coverage | Relevant | Missed | Status |
|---|---|---|---|---|
| `Apero` | 0.0% | 9 | 9 | ❌ |
| `Apero.Application` | 100.0% | 4 | 0 | ✅ |
| `Apero.Cache` | 90.4% | 21 | 2 | ✅ |
| `Apero.Cache.Adapter` | — | 0 | 0 | — (behaviour) |
| `Apero.Cache.Crypto` | 92.3% | 13 | 1 | ✅ |
| `Apero.Cache.ETS` | 88.0% | 25 | 3 | ✅ |
| `Apero.Cache.Supervisor` | 0.0% | 2 | 2 | ❌ |
| `Apero.Conf` | 76.6% | 90 | 21 | ⚠️ |
| `Apero.Crypto` | 0.0% | 29 | 29 | ❌ |
| `Apero.Crypto.Cipher` | 96.5% | 29 | 1 | ✅ |
| `Apero.Crypto.Hash` | 100.0% | 5 | 0 | ✅ |
| `Apero.Crypto.Key` | 73.6% | 19 | 5 | ⚠️ |
| `Apero.Crypto.Random` | 95.4% | 22 | 1 | ✅ |
| `Apero.Env` | 74.2% | 66 | 17 | ⚠️ |
| `Apero.File` | 0.0% | 28 | 28 | ❌ |
| `Apero.File.IO` | 0.0% | 53 | 53 | ❌ |
| `Apero.File.Path` | 0.0% | 54 | 54 | ❌ |
| `Apero.File.Tree` | 0.0% | 20 | 20 | ❌ |
| `Apero.File.Watcher` | 0.0% | 20 | 20 | ❌ |
| `Apero.Http` | 0.0% | 19 | 19 | ❌ |
| `Apero.Http.Adapter` | — | 0 | 0 | — (behaviour) |
| `Apero.Http.Adapter.Finch` | 0.0% | 28 | 28 | ❌ |
| `Apero.Http.Error` | 100.0% | 7 | 0 | ✅ |
| `Apero.Http.Finch` | 77.7% | 9 | 2 | ⚠️ |
| `Apero.Http.Method` | — | 0 | 0 | — (behaviour) |
| `Apero.Http.Method.Delete` | 100.0% | 2 | 0 | ✅ |
| `Apero.Http.Method.Get` | 100.0% | 1 | 0 | ✅ |
| `Apero.Http.Method.Patch` | 100.0% | 2 | 0 | ✅ |
| `Apero.Http.Method.Post` | 100.0% | 2 | 0 | ✅ |
| `Apero.Http.Method.Put` | 100.0% | 2 | 0 | ✅ |
| `Apero.Http.Method.Query` | 100.0% | 2 | 0 | ✅ |
| `Apero.Http.Request` | — | 0 | 0 | — (struct) |
| `Apero.Http.Response` | — | 0 | 0 | — (struct) |
| `Apero.Network` | 0.0% | 4 | 4 | ❌ |
| `Apero.OS` | 13.3% | 30 | 26 | ❌ |
| `Apero.Packages` | 0.0% | 22 | 22 | ❌ |
| `Apero.Proc` | 100.0% | 11 | 0 | ✅ |
| `Apero.Retry` | 65.7% | 35 | 12 | ⚠️ |
| **TOTAL** | **44.6%** | **708** | **393** | **⚠️** |

---

## 🔧 Top 5 Fixes Priority Order

| # | ID | Severity | Effort | Why this order |
|---|---|---|---|---|
| 1 | **P0-1** | 🔴 | 1h | `Jason.encode!` crash is a production bug — any non-serializable body kills the caller |
| 2 | **P0-2** | 🔴 | 0.5h | `Process.sleep(50)` is a time bomb under load; fix it and remove the sleep entirely |
| 3 | **P0-3** | 🔴 | 0.5h | API inconsistency breaks consumers — bare `:error` vs `{:error, _}` is a protocol violation |
| 4 | **P0-4** | 🔴 | 1h | Silent data loss — callers can never decrypt data encrypted with auto-generated key |
| 5 | **P1-1** | 🟠 | 2h | Dynamic `String.to_atom` is a DoS vector for any API that accepts untrusted config keys |

**Estimated total effort for all P0 fixes:** ~3 hours  
**Estimated total effort for all P1 fixes:** ~8 hours  
**Estimated total effort for all P2 fixes:** ~12 hours  

---

## Cómo usar esta auditoría

### Interpretación

- **P0 (🔴)**: Debe corregirse antes de cualquier release. Riesgo de crash, seguridad, o pérdida de datos.
- **P1 (🟠)**: Debe corregirse en el próximo ciclo. Degradación significativa de calidad o seguridad.
- **P2 (🟡)**: Debe corregirse cuando se toque el módulo afectado. Deuda técnica.
- **P3 (🟢)**: Conveniencia o estilo. Bajo impacto.

### Flujo de trabajo autónomo

Este documento, junto con `ARCHITECTURE.md` (diseño del proyecto) e `INDEX.md` (navegación de docs), contiene toda la información necesaria para abordar las correcciones de forma autónoma:

1. **Lee ARCHITECTURE.md** primero — entiende el diseño, subsistemas y decisiones clave.
2. **Lee INDEX.md** — localiza los archivos y módulos relevantes.
3. **Vuelve a esta auditoría** — prioriza por severidad (P0 → P1 → P2 → P3).
4. **Para cada hallazgo**: el fichero y línea están indicados. El código fuente relevante está en `lib/`.
5. **Ejecuta `mix test --cover`** antes y después para medir el impacto.
6. **Ejecuta `mix credo --all`** para garantizar que no introduces nuevas violaciones.
7. **Si el hallazgo implica cambiar una interfaz pública**, verifica los proyectos consumidores (listados en ARCHITECTURE.md §consumed-by).

### Dependencias entre proyectos

Apero es la **capa fundacional** del ecosistema. No depende de ningún otro proyecto Lorenzo-SF, por lo que puedes abordar esta auditoría de forma totalmente independiente.

**Todos los demás proyectos** (pote, alaja, arrea, trebejo, candil, botica, delfos) dependen de apero. Si modificas una interfaz pública de apero (tipos, behaviours, funciones exportadas), deberás actualizar los proyectos consumidores. Cada uno tiene su propia auditoría que detalla cómo usa apero.

### Checklist por severidad

**Al corregir un P0**:
- [ ] Aísla la causa raíz (línea exacta)
- [ ] Escribe un test que reproduzca el fallo **antes** de corregir
- [ ] Aplica la corrección
- [ ] Verifica que el test pasa
- [ ] Ejecuta `mix test --cover` — la cobertura no debe disminuir
- [ ] Ejecuta `mix credo --all` — cero nuevas violaciones
- [ ] Si cambia una interfaz pública, verifica proyectos consumidores

**Al corregir un P1**:
- [ ] Identifica todos los lugares donde se aplica el patrón (grep por el código similar)
- [ ] Testea el cambio (unitario + integración si aplica)
- [ ] Verifica `mix test --cover` no baja
- [ ] Si afecta a consumidores, actualiza sus tests también

**Al corregir P2/P3**:
- [ ] Corrige cuando toques el módulo por otra razón (boy-scout rule)
- [ ] No merecen un esfuerzo dedicado si no hay un bug reportado
