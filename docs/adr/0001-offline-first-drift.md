# ADR 0001 · Offline-first con Drift (SQLite) también en Web

- **Estado:** aceptada
- **Fecha:** 2026-11-15

## Contexto

La conexión en Cuba es lenta, cara e intermitente, con apagones frecuentes.
Una caja registradora no puede depender de internet para vender.

## Decisión

- La base de datos local (SQLite vía **Drift**) es la **fuente de verdad**
  en Android y en Web (SQLite compilado a WASM, persistido en
  OPFS/IndexedDB). La demo web corre **sin backend**.
- Dinero en **centavos enteros** y cantidades en **milésimas**; nunca
  `double` para importes.
- IDs **UUID v7** (únicos entre dispositivos y ordenables por tiempo) y
  borrado lógico (`deleted_at`) para poder sincronizar.
- Migraciones versionadas (`schemaVersion`) desde la primera versión
  publicada.

## Consecuencias

- (+) Vender, cobrar, cuadrar caja y ver reportes funciona sin conexión.
- (+) Un único código de datos para Android y Web.
- (−) En Web hay que servir `sqlite3.wasm` y `drift_worker.js` con versiones
  fijadas a las de `pubspec.lock`.
