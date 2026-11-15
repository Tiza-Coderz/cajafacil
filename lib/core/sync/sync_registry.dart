import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:drift/drift.dart';

/// Cómo reconstruir y guardar cada entidad sincronizable a partir de JSON.
class SyncEntity<D extends DataClass> {
  const SyncEntity(this.table, this.fromJson, this.updatedAt, this.deviceId);

  final TableInfo<Table, D> table;
  final D Function(Map<String, dynamic> json) fromJson;
  final DateTime Function(D row) updatedAt;
  final String Function(D row) deviceId;

  String get name => table.actualTableName;

  Future<D?> findLocal(AppDatabase db, String id) async {
    final idColumn = table.columnsByName['id']! as GeneratedColumn<String>;
    return (db.select(
      table,
    )..where((_) => idColumn.equals(id))).getSingleOrNull();
  }

  Future<void> _upsert(AppDatabase db, D row) =>
      db.into(table).insertOnConflictUpdate(row as Insertable<D>);

  /// Aplica [record] si gana a la versión local ("último cambio gana").
  /// Devuelve true si se aplicó. Toda la lógica tipada vive aquí para no
  /// invocar funciones genéricas desde fuera (varianza de tipos en Dart).
  Future<bool> applyIfNewer(AppDatabase db, RemoteRecord record) async {
    final local = await findLocal(db, record.id);
    if (local != null &&
        !record.winsOver(
          updatedAt(local).millisecondsSinceEpoch,
          deviceId(local),
        )) {
      return false;
    }
    await _upsert(db, fromJson(record.payload));
    return true;
  }
}

/// Entidades en orden de dependencias (las referenciadas primero), para que
/// las claves foráneas se cumplan al aplicar lo descargado.
List<SyncEntity<DataClass>> syncEntities(AppDatabase db) => [
  SyncEntity<BusinessSettingsRow>(
    db.businessSettings,
    BusinessSettingsRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<UserRow>(
    db.users,
    UserRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<ExchangeRateRow>(
    db.exchangeRates,
    ExchangeRateRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<CategoryRow>(
    db.categories,
    CategoryRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<ProductRow>(
    db.products,
    ProductRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<SupplierRow>(
    db.suppliers,
    SupplierRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<PurchaseRow>(
    db.purchases,
    PurchaseRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<PurchaseItemRow>(
    db.purchaseItems,
    PurchaseItemRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<CashSessionRow>(
    db.cashSessions,
    CashSessionRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<CashMovementRow>(
    db.cashMovements,
    CashMovementRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<SaleRow>(
    db.sales,
    SaleRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<SaleItemRow>(
    db.saleItems,
    SaleItemRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<SalePaymentRow>(
    db.salePayments,
    SalePaymentRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
  SyncEntity<StockMovementRow>(
    db.stockMovements,
    StockMovementRow.fromJson,
    (r) => r.updatedAt,
    (r) => r.deviceId,
  ),
];
