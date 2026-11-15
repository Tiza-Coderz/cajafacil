import 'dart:convert';

import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:cajafacil/core/sync/sync_registry.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

@immutable
class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.applied,
    required this.skipped,
  });

  final int pushed;

  /// Registros remotos que ganaron y se aplicaron localmente.
  final int applied;

  /// Registros remotos más viejos que la versión local (perdieron).
  final int skipped;
}

/// Sube la cola de cambios locales y baja los de otros equipos.
///
/// - **Subida**: lee `sync_outbox` en orden, deduplica por registro (solo
///   viaja la última versión) y borra lo enviado.
/// - **Bajada**: pide por `seq` del servidor, aplica "último cambio gana"
///   (fecha y, si empata, id de dispositivo) y recalcula existencias desde
///   el kardex, que es de solo inserción: así ninguna venta se pierde aunque
///   dos cajas vendan el mismo producto sin conexión.
class SyncEngine {
  SyncEngine(this._db, this._api) : _ledger = StockLedger(_db);

  final AppDatabase _db;
  final RemoteSyncApi _api;
  final StockLedger _ledger;

  static const cursorKey = 'sync_pull_seq';
  static const lastSyncKey = 'sync_last_at';

  late final Map<String, SyncEntity<DataClass>> _entities = {
    for (final e in syncEntities(_db)) e.name: e,
  };

  Future<SyncResult> sync() async {
    final pushed = await push();
    final (applied, skipped) = await pull();
    await _setState(lastSyncKey, '${_db.clock.now().millisecondsSinceEpoch}');
    return SyncResult(pushed: pushed, applied: applied, skipped: skipped);
  }

  Future<int> pendingCount() => _db.syncOutbox
      .count(where: (o) => o.status.equalsValue(OutboxStatus.sent).not())
      .getSingle();

  Future<DateTime?> lastSyncAt() async {
    final v = await _getState(lastSyncKey);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(v));
  }

  Future<int> push({int batchSize = 200}) async {
    final deviceId = await _db.deviceId();
    var total = 0;
    while (true) {
      final batch =
          await (_db.select(_db.syncOutbox)
                ..where((o) => o.status.equalsValue(OutboxStatus.sent).not())
                ..orderBy([(o) => OrderingTerm.asc(o.seq)])
                ..limit(batchSize))
              .get();
      if (batch.isEmpty) return total;

      // Solo la última versión de cada registro (se reemplaza en orden).
      final latest = <String, RemoteRecord>{};
      for (final o in batch) {
        final payload = (jsonDecode(o.payloadJson) as Map)
            .cast<String, Object?>();
        latest['${o.entity}/${o.entityId}'] = RemoteRecord(
          entity: o.entity,
          id: o.entityId,
          payload: payload,
          updatedAtMs:
              (payload['updatedAt'] as num?)?.toInt() ??
              o.updatedAt.millisecondsSinceEpoch,
          deviceId: (payload['deviceId'] as String?) ?? deviceId,
        );
      }
      final seqs = batch.map((o) => o.seq).toList();
      try {
        await _api.push(latest.values.toList());
      } on Object catch (e) {
        await (_db.update(
          _db.syncOutbox,
        )..where((o) => o.seq.isIn(seqs))).write(
          SyncOutboxCompanion.custom(
            attempts: _db.syncOutbox.attempts + const Constant(1),
            lastError: Variable(e.toString()),
            status: Variable(OutboxStatus.failed.name),
          ),
        );
        rethrow;
      }
      await (_db.delete(_db.syncOutbox)..where((o) => o.seq.isIn(seqs))).go();
      total += latest.length;
    }
  }

  Future<(int applied, int skipped)> pull({int pageSize = 500}) async {
    final deviceId = await _db.deviceId();
    var cursor = int.tryParse(await _getState(cursorKey) ?? '') ?? 0;
    var applied = 0;
    var skipped = 0;
    while (true) {
      final page = await _api.pull(
        afterSeq: cursor,
        excludeDeviceId: deviceId,
        limit: pageSize,
      );
      if (page.records.isEmpty) return (applied, skipped);

      final result = await AppDatabase.withoutOutbox(
        () => _db.transaction(() async {
          // Las claves foráneas se verifican al confirmar la transacción.
          await _db.customStatement('PRAGMA defer_foreign_keys = ON');
          final touchedProducts = <String>{};
          var a = 0;
          var s = 0;
          for (final r in page.records) {
            final entity = _entities[r.entity];
            if (entity == null) continue;
            if (!await entity.applyIfNewer(_db, r)) {
              s++;
              continue;
            }
            a++;
            if (r.entity == _db.products.actualTableName) {
              touchedProducts.add(r.id);
            } else if (r.entity == _db.stockMovements.actualTableName) {
              touchedProducts.add(r.payload['productId']! as String);
            }
          }
          // El stock es una proyección del kardex: se reconstruye.
          for (final productId in touchedProducts) {
            await _ledger.recomputeStock(productId);
          }
          await _setState(cursorKey, '${page.lastSeq}');
          return (a, s);
        }),
      );
      applied += result.$1;
      skipped += result.$2;
      cursor = page.lastSeq;
      if (page.records.length < pageSize) return (applied, skipped);
    }
  }

  Future<String?> _getState(String key) async => (await (_db.select(
    _db.syncState,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setState(String key, String value) => _db
      .into(_db.syncState)
      .insertOnConflictUpdate(
        SyncStateCompanion.insert(key: key, value: value),
      );
}
