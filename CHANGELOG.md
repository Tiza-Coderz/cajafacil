# Changelog

Todos los cambios relevantes de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y versionado [SemVer](https://semver.org/lang/es/).

## [Unreleased]

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

[Unreleased]: https://github.com/Tiza-Coderz/cajafacil/compare/v0.1.0...develop
[0.1.0]: https://github.com/Tiza-Coderz/cajafacil/releases/tag/v0.1.0
