# Changelog

Todos los cambios relevantes de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y versionado [SemVer](https://semver.org/lang/es/).

## [Unreleased]

## [0.2.0] - 2026-11-15

Catálogo de productos con precios en USD y CUP, tasa de cambio del día y
una demo web pensada para conexiones lentas.

### Añadido

- Tasa de cambio USD→CUP del día con historial, autor, nota y aviso ante
  cambios bruscos (≥ 15 %).
- Catálogo de productos: categoría, código de barras (escáner con cámara y
  entrada manual), foto comprimida, unidad, costo, precio USD y precio CUP
  calculado con la tasa o fijo.
- Búsqueda por nombre o código, filtros por categoría y bajo stock.
- Kardex inicial al crear productos; el stock es una proyección de
  movimientos de solo inserción (seguro para sincronizar varios equipos).
- Demo: 60 productos cubanos con EAN-13 válidos y 15 días de tasa.
- Íconos de marca y manifest PWA.

### Cambiado

- Esquema de base de datos v2 (fotos de productos); migración automática.

### Rendimiento

- La versión web ya no depende de CDNs de Google: CanvasKit y fuentes se
  sirven desde el propio sitio. Primer contenido visible en 0,3 s (antes,
  ~15 s en blanco).

## [0.1.0] - 2026-11-15

Primera base funcional: la app arranca offline en Android y Web y permite
acceder por usuario con PIN.

### Añadido

- Proyecto Flutter (Android + Web) con lints estrictos y CI en GitHub Actions
  (formato, análisis, tests con cobertura y build web).
- Núcleo monetario en Dart puro: `Money` en centavos enteros, tasa USD→CUP,
  redondeo de CUP a 1/5/10 pesos y formato cubano.
- Base de datos local con Drift (SQLite nativo y WASM en Web) con el esquema
  completo: catálogo, ventas, caja, kardex y cola de sincronización.
- Patrón *outbox* transaccional para la futura sincronización con Supabase.
- Acceso con PIN por usuario y roles Dueño, Encargado y Cajero con matriz
  de permisos; bloqueo temporal tras 5 intentos fallidos.
- Hash de PIN y contraseñas con PBKDF2-HMAC-SHA256.
- Modo demo: "Mini-mercado La Esquina, Playa" con usuarios de prueba,
  credenciales visibles en el acceso y botón "Restablecer demo".
- Menú de inicio y rutas protegidas según permisos.

[Unreleased]: https://github.com/Tiza-Coderz/cajafacil/compare/v0.2.0...develop
[0.2.0]: https://github.com/Tiza-Coderz/cajafacil/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Tiza-Coderz/cajafacil/releases/tag/v0.1.0
