import 'package:cajafacil/core/database/converters.dart';
import 'package:drift/drift.dart';

/// Columnas comunes a toda tabla sincronizable.
///
/// - `id`: UUID v7 (ordenable por tiempo, sin colisiones entre dispositivos).
/// - `updatedAt`: base de la resolución "último cambio gana".
/// - `deletedAt`: borrado lógico, necesario para propagar borrados.
mixin SyncColumns on Table {
  TextColumn get id => text()();

  IntColumn get createdAt => integer().map(const EpochMsConverter())();

  IntColumn get updatedAt => integer().map(const EpochMsConverter())();

  IntColumn get deletedAt =>
      integer().map(const EpochMsConverter()).nullable()();

  TextColumn get deviceId => text()();
}
