# Which module when?

Guía rápida para elegir el módulo correcto de apero según el problema.

## Retry, backoff y rate limiting

| Necesitas | Módulo | Por qué |
|-----------|--------|---------|
| Reintentar una operación N veces con espera | `Apero.Retry` | Bucles de retry con callback `on_retry`, útil para operaciones síncronas con resultado |
| Calcular la espera entre reintentos | `Apero.Backoff` | Delays exponenciales con jitter (full o decorrelated); puro y testeable |
| Limitar peticiones por segundo a una API | `Apero.RateLimit` | Token bucket / leaky bucket por nombre; seguro bajo concurrencia |
| Cachear resultados de operaciones caras | `Apero.Cache` | Cache en memoria (ETS) con expiración |

### Flujo típico combinado

```elixir
# 1. Configura el rate limiter (una vez por nombre)
Apero.RateLimit.new(name: :llm_api, capacity: 10, refill_per_second: 1.0)

# 2. Antes de llamar a la API, espera a tener token
Apero.RateLimit.wait(:llm_api, 1, 5000)

# 3. Si falla la llamada, reintenta con backoff
backoff = Apero.Backoff.new(100, 5000)

Apero.Retry.with(
  fn -> call_api() end,
  attempts: 3,
  on_retry: fn _ctx -> Apero.Backoff.sleep(backoff, _ctx.attempt) end
)
```

**Regla práctica**:
- `Retry` = cuándo reintentar (control de flujo).
- `Backoff` = cuánto esperar entre reintentos.
- `RateLimit` = no saturar el servicio de origen.
- `Cache` = no llamar al servicio si ya lo hiciste hace poco.

## Escritura de archivos

| Necesitas | Módulo | Por qué |
|-----------|--------|---------|
| Escribir un archivo que otro proceso puede leer mientras escribes | `Apero.Atomic.File.write/3` | Escribe a `.tmp` + `rename` atómico; el lector nunca ve contenido parcial |
| Config store / checkpoint que se actualiza en su sitio | `Apero.Atomic.File.replace/3` | Lee, transforma y escribe atómicamente; no toca el original si la transformación falla |
| Log append-only / cola de eventos en disco | `Apero.Jsonl.append!/3` | Una línea por evento, tolerante a crashes (línea truncada se descarta) |
| Persistir una snapshot completa | `Apero.Jsonl.write!/3` | Reescribe todo el archivo en un solo write |
| Archivo temporal de una sola vez, nadie más lo lee | `File.write/2` | Suficiente y más rápido |

**Regla práctica**: si el archivo es un *estado* que otros leen (config,
checkpoints, colas), usa `Apero.Atomic.File` o `Apero.Jsonl`. Si es un
log efímero de un solo proceso, `File.write/2` basta.

## Tiempo

| Necesitas | Módulo | Por qué |
|-----------|--------|---------|
| Timestamp actual (para logs, metadata) | `Apero.Clock.now/0` | Inyectable en tests con `with_fixed/2` |
| Medir duraciones / timeouts | `Apero.Clock.monotonic_ms/0` | Monotónico, no afectado por cambios de reloj ni por el override de test |
| Testear código time-dependent sin sleeps | `Apero.Clock.with_fixed/2` | Escopa el override a una sola llamada y restaura aunque falle |

**Regla práctica**: usa `Apero.Clock` en cualquier módulo del kit que
dependa del tiempo — así el resto del stack puede testearse sin sleeps.
