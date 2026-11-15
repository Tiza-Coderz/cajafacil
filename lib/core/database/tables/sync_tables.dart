import 'package:cajafacil/core/database/converters.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:drift/drift.dart';

/// Cola de operaciones pendientes de subir (patrón "transactional outbox").
///
/// Cada escritura de un repositorio inserta aquí, en la misma transacción,
/// el registro modificado. El motor de sincronización la vacía cuando hay
/// conexión.
@DataClassName('OutboxRow')
@TableIndex(name: 'idx_outbox_status', columns: {#status, #seq})
class SyncOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get op => textEnum<SyncOp>()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAt => integer().map(const EpochMsConverter())();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => textEnum<OutboxStatus>().withDefault(
    Constant(OutboxStatus.pending.name),
  )();
}

/// Clave-valor para estado de sincronización (device_id, last_pulled_at...).
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
