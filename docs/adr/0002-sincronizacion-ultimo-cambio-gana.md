# ADR 0002 · Sincronización opcional con "último cambio gana"

- **Estado:** aceptada
- **Fecha:** 2026-11-15

## Contexto

Las mipymes cubanas trabajan con conexión intermitente y cara. La app debe
vender sin internet (la BD local es la fuente de verdad) y, si el negocio
lo desea, compartir datos entre varias cajas o con el dueño fuera del local.

## Decisión

1. **Outbox transaccional.** Cada escritura sincronizable guarda la fila y
   una entrada en `sync_outbox` en la misma transacción
   (`AppDatabase.writeSynced`). Nunca se pierde un cambio aunque la app se
   cierre.
2. **Servidor agnóstico al esquema.** Supabase guarda cada fila como JSON
   en `sync_records(business_id, entity, id, payload, updated_at,
   device_id, seq)`. Agregar columnas en la app no exige migrar el servidor.
3. **Último cambio gana** por `updated_at` (ms del dispositivo); si empata,
   gana el `device_id` mayor. La regla se aplica **en el servidor** (trigger)
   y **en el cliente** al bajar cambios, con el mismo criterio.
4. **Cursor de descarga = `seq` del servidor**, no la fecha del cliente: un
   equipo que estuvo días offline sube cambios "viejos" que de otro modo
   nadie bajaría.
5. **El stock no se sincroniza como valor.** Es una proyección local de
   `stock_movements` (solo inserción, nunca en conflicto). Tras bajar
   movimientos se recalcula. Actualizar la caché de stock no toca
   `updated_at` del producto, para que una venta no "pise" un cambio de
   precio hecho en otra caja.
6. **Ahorro de datos:** solo viaja la última versión de cada registro y no
   se descargan los cambios propios.

## Consecuencias

- (+) Ventas simultáneas sin conexión en varias cajas no se pierden
  (cubierto por `test/core/sync/sync_engine_test.dart`).
- (+) La app funciona igual sin Supabase (`SYNC_ENABLED=false`).
- (−) "Último cambio gana" descarta la edición más vieja de un mismo campo
  (p. ej. dos personas cambian el mismo precio). Es aceptable para un
  catálogo de bodega; un CRDT sería excesivo.
- (−) Los relojes desajustados afectan la resolución. Mitigación futura:
  corregir con la hora del servidor al sincronizar.
