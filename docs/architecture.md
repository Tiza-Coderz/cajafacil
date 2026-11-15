# Arquitectura de CajaFácil

## Vista general

```
┌──────────────────────────── presentation ────────────────────────────┐
│ Pantallas y widgets (Flutter) · providers Riverpod · go_router       │
└──────────────┬───────────────────────────────────────────────────────┘
               │ usa casos de uso / servicios del dominio
┌──────────────▼──────────────── domain ───────────────────────────────┐
│ Entidades (Freezed) · contratos de repositorio · reglas en Dart puro │
│ SaleCalculator · PaymentCalculator · CashReconciliation ·            │
│ InventoryRules · ProductPricing · RateValidator                      │
└──────────────┬───────────────────────────────────────────────────────┘
               │ implementado por
┌──────────────▼───────────────── data ────────────────────────────────┐
│ Repositorios Drift · StockLedger (kardex) · consultas SQL de reportes│
└──────────────┬───────────────────────────────────────────────────────┘
               │
┌──────────────▼──────── core/database (Drift) ────────┐   ┌── opcional ──┐
│ SQLite (Android) / SQLite WASM (Web) · outbox        │◀─▶│ Supabase     │
└──────────────────────────────────────────────────────┘   │ sync_records │
                                                           └──────────────┘
```

- **El dominio no depende de Flutter ni de la BD.** Por eso la lógica de
  dinero, vuelto y cuadre se prueba con tests rápidos y deterministas.
- **Las pantallas preguntan por permisos, no por roles**
  (`Permission.viewCostsAndProfit`), así cambiar la matriz no toca la UI.
- **Inyección con Riverpod**: cada repositorio es un provider; en tests se
  sobreescribe la BD con una en memoria.

## Modelo de datos

Toda tabla sincronizable tiene `id` (UUID v7), `created_at`, `updated_at`
(ms UTC), `deleted_at` y `device_id`.

| Tabla | Propósito |
|---|---|
| `business_settings` | Datos del negocio, moneda principal, redondeo CUP |
| `users` | Usuarios, rol, hash de PIN y contraseña (PBKDF2) |
| `exchange_rates` | Historial de tasas USD→CUP |
| `categories`, `products` | Catálogo; precio base USD, CUP automático o fijo |
| `suppliers`, `purchases`, `purchase_items` | Entradas de mercancía |
| `stock_movements` | **Kardex** (solo inserción); fuente de la existencia |
| `cash_sessions`, `cash_movements` | Turnos de caja y entradas/salidas |
| `sales`, `sale_items`, `sale_payments` | Ventas con tasa y precios congelados |
| `sync_outbox`, `sync_state` | Cola de sincronización y estado local |

Migraciones: `schemaVersion` 3 (v2 fotos de producto, v3 precio CUP por
línea de venta), con `onUpgrade` incremental.

## Flujos críticos

### Venta

1. El carrito congela precio USD y CUP de cada línea al añadirla.
2. `SaleCalculator` calcula totales (descuentos por línea y global; CUP
   redondeado según el negocio).
3. `PaymentCalculator` evalúa los pagos: todo en USD se liquida en USD;
   cualquier mezcla, en CUP con la tasa congelada. El vuelto siempre se
   redondea hacia abajo.
4. `SaleRepository.completeSale` escribe en **una transacción** venta,
   líneas, pagos y movimientos de kardex (vía `StockLedger`).

### Cierre de caja

`CashReconciliation`: esperado = fondo + efectivo recibido − vuelto +
entradas − salidas, **por moneda**. Los pagos electrónicos se informan
aparte. La diferencia contado − esperado queda registrada con el desglose
por billetes.

### Sincronización

Ver [ADR 0002](adr/0002-sincronizacion-ultimo-cambio-gana.md).

## Rendimiento en Web

- Sin CDNs de Google: CanvasKit y Roboto se sirven desde el mismo sitio.
- Splash en HTML/CSS visible en ~0,3 s.
- Seed de la demo en dos fases: base en primer plano (~1 s) y 2 semanas de
  historial en segundo plano, una transacción por día.
- Reportes agregados en SQL (no en memoria).
