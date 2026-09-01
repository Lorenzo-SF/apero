# Contributing

Gracias por contribuir a apero.

## Flujo de trabajo

1. Crea una rama desde `main`: `git checkout -b feat/xxx`
2. Implementa con tests
3. Ejecuta el alias de lint completo antes de commitear:

   ```bash
   mix lint
   ```

   Equivale a:

   ```bash
   mix format --check-formatted
   mix compile --warnings-as-errors
   mix dialyzer
   mix credo --strict
   mix test --cover
   ```

4. Commit con Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
5. PR pequeño (< 500 líneas), una cosa lógica, revisable.

## Calidad exigida

- `@moduledoc` + `@doc` + `@spec` en toda función pública nueva.
- Tests que cubren la API pública; usa property tests (`stream_data`)
  para propiedades (colisiones, determinismo, monotonicidad).
- No añadas deps runtime nuevas sin justificación; el kit entero
  (candil, delfos, botica) se construye sobre apero.
- `mix format` antes de commitear — el CI lo comprueba.

## CI

`.github/workflows/ci.yml` ejecuta en cada push/PR:

1. `mix format --check-formatted`
2. `mix credo --strict`
3. Compilación (job `test`)
4. Dialyzer (solo `main`)

El step de `mix test --cover` está desactivado en CI por fallos
opacos con Elixir 1.19/OTP 28.1 (ver comentario en el workflow);
se ejecuta localmente con `mix qa` o `mix lint`.
