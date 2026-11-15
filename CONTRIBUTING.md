# Guía de contribución

## Flujo de ramas (Git Flow)

| Rama | Propósito |
|---|---|
| `main` | Código en producción. Solo recibe merges desde `release/*` y `hotfix/*`. Cada merge lleva tag `vX.Y.Z`. |
| `develop` | Rama de integración (por defecto). Siempre debe compilar y pasar CI. |
| `feature/<area>-<descripcion>` | Nueva funcionalidad. Sale de `develop` y vuelve por Pull Request. |
| `release/X.Y.0` | Estabilización de una versión: changelog, versión en `pubspec.yaml`, correcciones menores. |
| `hotfix/X.Y.Z` | Corrección urgente sobre `main`; se integra también en `develop`. |

## Commits

Se usa [Conventional Commits](https://www.conventionalcommits.org/es/):

```
feat(pos): calcular vuelto en la moneda elegida
fix(caja): diferencia negativa mostraba signo incorrecto
test(money): casos de redondeo a 5 CUP
```

Tipos: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`.
Ámbitos frecuentes: `core`, `db`, `auth`, `products`, `rate`, `pos`, `inventory`, `cash`, `reports`, `settings`, `sync`, `demo`.

## Antes de abrir un PR

```bash
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze --fatal-infos
flutter test
```
