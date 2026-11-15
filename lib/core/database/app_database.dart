import 'dart:convert';

import 'package:cajafacil/core/database/connection.dart';
import 'package:cajafacil/core/database/converters.dart';
import 'package:cajafacil/core/database/tables/business_tables.dart';
import 'package:cajafacil/core/database/tables/catalog_tables.dart';
import 'package:cajafacil/core/database/tables/sales_tables.dart';
import 'package:cajafacil/core/database/tables/sync_tables.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    BusinessSettings,
    Users,
    ExchangeRates,
    Categories,
    Products,
    Suppliers,
    Purchases,
    PurchaseItems,
    StockMovements,
    CashSessions,
    CashMovements,
    Sales,
    SaleItems,
    SalePayments,
    SyncOutbox,
    SyncState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(
    super.e, {
    this.clock = const Clock(),
    this.ids = const IdGenerator(),
  });

  factory AppDatabase.open() => AppDatabase(openConnection());

  final Clock clock;
  final IdGenerator ids;

  static const _deviceIdKey = 'device_id';
  String? _deviceId;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Identificador estable de este dispositivo (se crea la primera vez).
  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final existing = await (select(
      syncState,
    )..where((s) => s.key.equals(_deviceIdKey))).getSingleOrNull();
    if (existing != null) return _deviceId = existing.value;
    final id = ids.newId();
    await into(syncState).insert(
      SyncStateCompanion.insert(key: _deviceIdKey, value: id),
    );
    return _deviceId = id;
  }

  /// Inserta o actualiza [row] y encola el cambio para sincronizar
  /// dentro de una única transacción (patrón outbox).
  Future<void> writeSynced<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    D row, {
    required String entityId,
    SyncOp op = SyncOp.upsert,
  }) {
    return transaction(() async {
      await into(table).insertOnConflictUpdate(row as Insertable<D>);
      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          entity: table.actualTableName,
          entityId: entityId,
          op: op,
          payloadJson: jsonEncode(row.toJson()),
          updatedAt: clock.now(),
        ),
      );
    });
  }

  /// Borra todos los datos (usado por "Restablecer demo").
  Future<void> wipeAll() {
    return transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');
      for (final table in allTables.toList().reversed) {
        if (table.actualTableName == syncState.actualTableName) continue;
        await delete(table).go();
      }
      await customStatement('PRAGMA foreign_keys = ON');
    });
  }
}
