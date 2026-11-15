import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Abre la BD en la plataforma actual:
/// - Android: SQLite nativo en el directorio de la app.
/// - Web: SQLite compilado a WASM, persistido en OPFS o IndexedDB.
///   Requiere `web/sqlite3.wasm` y `web/drift_worker.js` (versiones fijadas
///   a las de `pubspec.lock`).
QueryExecutor openConnection({String name = 'cajafacil'}) {
  return driftDatabase(
    name: name,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
