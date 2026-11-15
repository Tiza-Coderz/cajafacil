import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/inventory/domain/entities/inventory_entities.dart';
import 'package:cajafacil/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:cajafacil/features/inventory/domain/services/inventory_rules.dart';
import 'package:drift/drift.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._db, this._ledger);

  final AppDatabase _db;
  final StockLedger _ledger;

  @override
  Stream<List<Supplier>> watchSuppliers() {
    final query = _db.select(_db.suppliers)
      ..where((s) => s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.asc(s.name)]);
    return query.watch().map(
      (rows) => [
        for (final s in rows)
          Supplier(id: s.id, name: s.name, phone: s.phone, notes: s.notes),
      ],
    );
  }

  @override
  Future<Supplier> createSupplier({required String name, String? phone}) async {
    final now = _db.clock.now();
    final cleanPhone = phone?.trim();
    final row = SupplierRow(
      id: _db.ids.newId(),
      createdAt: now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      name: name.trim(),
      phone: (cleanPhone?.isEmpty ?? true) ? null : cleanPhone,
    );
    await _db.writeSynced(_db.suppliers, row, entityId: row.id);
    return Supplier(id: row.id, name: row.name, phone: row.phone);
  }

  @override
  Future<String> registerPurchase(
    PurchaseDraft draft, {
    required String userId,
  }) {
    if (draft.items.isEmpty) {
      throw ArgumentError('La entrada no tiene productos.');
    }
    if (draft.items.any((i) => i.qtyMilli <= 0 || i.unitCostUsd.isNegative)) {
      throw ArgumentError('Cantidades y costos deben ser positivos.');
    }
    return _db.transaction(() async {
      final now = _db.clock.now();
      final date = draft.date ?? now;
      final deviceId = await _db.deviceId();
      final purchaseId = _db.ids.newId();
      final total = InventoryRules.purchaseTotal(
        draft.items.map((i) => (i.qtyMilli, i.unitCostUsd)),
      );
      String? clean(String? v) =>
          (v?.trim().isEmpty ?? true) ? null : v!.trim();

      await _db.writeSynced(
        _db.purchases,
        PurchaseRow(
          id: purchaseId,
          createdAt: date,
          updatedAt: now,
          deviceId: deviceId,
          supplierId: draft.supplierId,
          userId: userId,
          date: date,
          invoiceRef: clean(draft.invoiceRef),
          totalCostUsdCents: total.cents,
          note: clean(draft.note),
        ),
        entityId: purchaseId,
      );

      for (final item in draft.items) {
        final itemRow = PurchaseItemRow(
          id: _db.ids.newId(),
          createdAt: date,
          updatedAt: now,
          deviceId: deviceId,
          purchaseId: purchaseId,
          productId: item.productId,
          qtyMilli: item.qtyMilli,
          unitCostUsdCents: item.unitCostUsd.cents,
        );
        await _db.writeSynced(_db.purchaseItems, itemRow, entityId: itemRow.id);

        // Costo promedio ponderado ANTES de sumar la existencia.
        final product = await (_db.select(
          _db.products,
        )..where((p) => p.id.equals(item.productId))).getSingle();
        final newCost = InventoryRules.weightedAverageCost(
          stockMilli: product.stockMilli,
          currentCost: Money.usd(product.costUsdCents),
          incomingMilli: item.qtyMilli,
          incomingCost: item.unitCostUsd,
        );
        await _db.writeSynced(
          _db.products,
          product.copyWith(costUsdCents: newCost.cents, updatedAt: now),
          entityId: product.id,
        );
        await _ledger.record(
          productId: item.productId,
          type: StockMovementType.purchase,
          qtyDeltaMilli: item.qtyMilli,
          unitCostUsdCents: item.unitCostUsd.cents,
          userId: userId,
          refId: purchaseId,
          at: date,
        );
      }
      return purchaseId;
    });
  }

  @override
  Stream<List<PurchaseSummary>> watchPurchases({int limit = 50}) {
    final p = _db.purchases;
    final count = _db.purchaseItems.id.count();
    final query =
        _db.select(p).join([
            innerJoin(_db.users, _db.users.id.equalsExp(p.userId)),
            leftOuterJoin(
              _db.suppliers,
              _db.suppliers.id.equalsExp(p.supplierId),
            ),
            leftOuterJoin(
              _db.purchaseItems,
              _db.purchaseItems.purchaseId.equalsExp(p.id),
            ),
          ])
          ..addColumns([count])
          ..where(p.deletedAt.isNull())
          ..groupBy([p.id])
          ..orderBy([OrderingTerm.desc(p.date)])
          ..limit(limit);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          PurchaseSummary(
            id: r.readTable(p).id,
            date: r.readTable(p).date,
            totalCostUsd: Money.usd(r.readTable(p).totalCostUsdCents),
            itemCount: r.read(count) ?? 0,
            userName: r.readTable(_db.users).name,
            supplierName: r.readTableOrNull(_db.suppliers)?.name,
            invoiceRef: r.readTable(p).invoiceRef,
          ),
      ],
    );
  }

  @override
  Future<int> adjust({
    required String productId,
    required AdjustmentReason reason,
    required int quantityMilli,
    required String userId,
    String? note,
  }) {
    return _db.transaction(() async {
      final product = await (_db.select(
        _db.products,
      )..where((p) => p.id.equals(productId))).getSingle();
      final delta = InventoryRules.adjustmentDelta(
        reason: reason,
        quantityMilli: quantityMilli,
        currentStockMilli: product.stockMilli,
      );
      if (delta == 0) return product.stockMilli;
      final cleanNote = note?.trim();
      return _ledger.record(
        productId: productId,
        type: StockMovementType.adjustment,
        reason: reason,
        qtyDeltaMilli: delta,
        unitCostUsdCents: product.costUsdCents,
        userId: userId,
        note: (cleanNote?.isEmpty ?? true) ? null : cleanNote,
      );
    });
  }

  @override
  Stream<List<KardexEntry>> watchKardex(String productId, {int limit = 200}) {
    final m = _db.stockMovements;
    final query =
        _db.select(m).join([
            innerJoin(_db.users, _db.users.id.equalsExp(m.userId)),
          ])
          ..where(m.productId.equals(productId) & m.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(m.createdAt)])
          ..limit(limit);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          KardexEntry(
            id: r.readTable(m).id,
            date: r.readTable(m).createdAt,
            type: r.readTable(m).type,
            reason: r.readTable(m).reason,
            qtyDeltaMilli: r.readTable(m).qtyDeltaMilli,
            balanceAfterMilli: r.readTable(m).balanceAfterMilli,
            unitCostUsd: Money.usd(r.readTable(m).unitCostUsdCents),
            userName: r.readTable(_db.users).name,
            note: r.readTable(m).note,
            refId: r.readTable(m).refId,
          ),
      ],
    );
  }
}
