import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:drift/drift.dart';

/// Único punto por el que cambia la existencia de un producto.
///
/// Cada cambio inserta un movimiento en el kardex (`stock_movements`, solo
/// inserción) y actualiza `products.stock_milli`, que es una caché de la
/// suma de movimientos. Así la sincronización entre dispositivos no pierde
/// ventas: los movimientos nunca entran en conflicto y el stock se puede
/// recalcular con [recomputeStock].
class StockLedger {
  StockLedger(this._db);

  final AppDatabase _db;

  /// Registra un movimiento y devuelve la nueva existencia (en milésimas).
  Future<int> record({
    required String productId,
    required StockMovementType type,
    required int qtyDeltaMilli,
    required int unitCostUsdCents,
    required String userId,
    AdjustmentReason? reason,
    String? refId,
    String? note,
    DateTime? at,
  }) {
    return _db.transaction(() async {
      final product = await (_db.select(
        _db.products,
      )..where((p) => p.id.equals(productId))).getSingle();
      final now = at ?? _db.clock.now();
      final deviceId = await _db.deviceId();
      final balance = product.stockMilli + qtyDeltaMilli;

      final movement = StockMovementRow(
        id: _db.ids.newId(),
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
        productId: productId,
        type: type,
        reason: reason,
        qtyDeltaMilli: qtyDeltaMilli,
        unitCostUsdCents: unitCostUsdCents,
        balanceAfterMilli: balance,
        refId: refId,
        userId: userId,
        note: note,
      );
      await _db.writeSynced(
        _db.stockMovements,
        movement,
        entityId: movement.id,
      );
      await _db.writeSynced(
        _db.products,
        product.copyWith(stockMilli: balance, updatedAt: now),
        entityId: productId,
      );
      return balance;
    });
  }

  /// Recalcula la existencia desde el kardex (tras sincronizar).
  Future<int> recomputeStock(String productId) async {
    final sum = _db.stockMovements.qtyDeltaMilli.sum();
    final query = _db.selectOnly(_db.stockMovements)
      ..addColumns([sum])
      ..where(
        _db.stockMovements.productId.equals(productId) &
            _db.stockMovements.deletedAt.isNull(),
      );
    final total = (await query.getSingle()).read(sum) ?? 0;
    await (_db.update(_db.products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(stockMilli: Value(total)));
    return total;
  }
}
