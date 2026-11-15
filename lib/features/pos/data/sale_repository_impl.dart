import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/pos/domain/entities/sale_receipt.dart';
import 'package:cajafacil/features/pos/domain/repositories/sale_repository.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:drift/drift.dart';

class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl(this._db, this._ledger);

  final AppDatabase _db;
  final StockLedger _ledger;

  static const _seqKey = 'sale_seq';

  /// Número correlativo legible por dispositivo: "A3-000123".
  Future<String> _nextNumber() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(_seqKey))).getSingleOrNull();
    final next = (int.tryParse(row?.value ?? '') ?? 0) + 1;
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(key: _seqKey, value: '$next'),
        );
    final prefix = (await _db.deviceId())
        .replaceAll('-', '')
        .substring(0, 2)
        .toUpperCase();
    return '$prefix-${next.toString().padLeft(6, '0')}';
  }

  @override
  Future<SaleReceipt> completeSale(CompleteSaleCommand c) {
    if (c.lines.isEmpty) {
      throw ArgumentError('No se puede registrar una venta sin productos.');
    }
    return _db.transaction(() async {
      final session = await (_db.select(
        _db.cashSessions,
      )..where((s) => s.id.equals(c.sessionId))).getSingleOrNull();
      if (session == null || session.status != CashSessionStatus.open) {
        throw const CashSessionNotOpenException();
      }

      final now = c.createdAt ?? _db.clock.now();
      final deviceId = await _db.deviceId();
      final saleId = _db.ids.newId();
      final t = c.totals;

      final sale = SaleRow(
        id: saleId,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
        number: await _nextNumber(),
        sessionId: c.sessionId,
        cashierId: c.cashierId,
        rateCupPerUsdX100: c.rate.cupPerUsdX100,
        subtotalUsdCents: t.subtotalUsd.cents,
        discountType: c.globalDiscount?.type,
        discountValue: c.globalDiscount?.value ?? 0,
        discountUsdCents: t.totalDiscountUsd.cents,
        totalUsdCents: t.totalUsd.cents,
        totalCupCents: t.totalCup.cents,
        totalCostUsdCents: t.costUsd.cents,
        changeCurrency: c.change.isZero ? null : c.change.currency,
        changeCents: c.change.cents,
        status: SaleStatus.completed,
      );
      await _db.writeSynced(_db.sales, sale, entityId: saleId);

      for (final (i, line) in c.lines.indexed) {
        final lt = t.lines[i];
        final item = SaleItemRow(
          id: _db.ids.newId(),
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
          saleId: saleId,
          productId: line.productId,
          nameSnapshot: line.name,
          qtyMilli: line.qtyMilli,
          unitPriceUsdCents: line.unitPriceUsd.cents,
          unitCostUsdCents: line.unitCostUsd.cents,
          discountType: line.discount?.type,
          discountValue: line.discount?.value ?? 0,
          discountUsdCents: lt.discountUsd.cents,
          lineTotalUsdCents: lt.totalUsd.cents,
          unitPriceCupCents: line.unitPriceCup.cents,
          lineTotalCupCents: lt.totalCup.cents,
        );
        await _db.writeSynced(_db.saleItems, item, entityId: item.id);
        await _ledger.record(
          productId: line.productId,
          type: StockMovementType.sale,
          qtyDeltaMilli: -line.qtyMilli,
          unitCostUsdCents: line.unitCostUsd.cents,
          userId: c.cashierId,
          refId: saleId,
          at: now,
        );
      }

      for (final p in c.payments) {
        final payment = SalePaymentRow(
          id: _db.ids.newId(),
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
          saleId: saleId,
          method: p.method,
          currency: p.amount.currency,
          amountCents: p.amount.cents,
          reference: p.reference,
        );
        await _db.writeSynced(_db.salePayments, payment, entityId: payment.id);
      }
      return (await receipt(saleId))!;
    });
  }

  @override
  Future<void> voidSale({
    required String saleId,
    required String reason,
    required String userId,
  }) {
    return _db.transaction(() async {
      final sale = await (_db.select(
        _db.sales,
      )..where((s) => s.id.equals(saleId))).getSingle();
      if (sale.status == SaleStatus.voided) {
        throw const SaleNotVoidableException('La venta ya está anulada.');
      }
      final session = await (_db.select(
        _db.cashSessions,
      )..where((s) => s.id.equals(sale.sessionId))).getSingle();
      if (session.status != CashSessionStatus.open) {
        throw const SaleNotVoidableException(
          'Solo se pueden anular ventas del turno abierto.',
        );
      }
      final now = _db.clock.now();
      await _db.writeSynced(
        _db.sales,
        sale.copyWith(
          status: SaleStatus.voided,
          voidReason: Value(reason.trim()),
          voidedBy: Value(userId),
          updatedAt: now,
        ),
        entityId: saleId,
      );
      final items = await (_db.select(
        _db.saleItems,
      )..where((i) => i.saleId.equals(saleId))).get();
      for (final item in items) {
        await _ledger.record(
          productId: item.productId,
          type: StockMovementType.saleVoid,
          qtyDeltaMilli: item.qtyMilli,
          unitCostUsdCents: item.unitCostUsdCents,
          userId: userId,
          refId: saleId,
          note: reason.trim(),
        );
      }
    });
  }

  @override
  Future<SaleReceipt?> receipt(String saleId) async {
    final query = _db.select(_db.sales).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.sales.cashierId)),
    ])..where(_db.sales.id.equals(saleId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _toReceipt(row.readTable(_db.sales), row.readTable(_db.users).name);
  }

  Future<SaleReceipt> _toReceipt(SaleRow sale, String cashierName) async {
    final items = await (_db.select(
      _db.saleItems,
    )..where((i) => i.saleId.equals(sale.id))).get();
    final payments = await (_db.select(
      _db.salePayments,
    )..where((p) => p.saleId.equals(sale.id))).get();
    final units = {
      for (final p
          in await (_db.select(_db.products)..where(
                (p) => p.id.isIn(items.map((i) => i.productId)),
              ))
              .get())
        p.id: p.unit,
    };
    return SaleReceipt(
      id: sale.id,
      number: sale.number,
      createdAt: sale.createdAt,
      cashierName: cashierName,
      rate: ExchangeRate(sale.rateCupPerUsdX100),
      lines: [
        for (final i in items)
          ReceiptLine(
            name: i.nameSnapshot,
            unit: units[i.productId] ?? ProductUnit.unit,
            qtyMilli: i.qtyMilli,
            unitPriceUsd: Money.usd(i.unitPriceUsdCents),
            unitPriceCup: Money.cup(i.unitPriceCupCents),
            discountUsd: Money.usd(i.discountUsdCents),
            totalUsd: Money.usd(i.lineTotalUsdCents),
            totalCup: Money.cup(i.lineTotalCupCents),
          ),
      ],
      payments: [
        for (final p in payments)
          Payment(
            method: p.method,
            amount: Money(p.amountCents, p.currency),
            reference: p.reference,
          ),
      ],
      subtotalUsd: Money.usd(sale.subtotalUsdCents),
      discountUsd: Money.usd(sale.discountUsdCents),
      totalUsd: Money.usd(sale.totalUsdCents),
      totalCup: Money.cup(sale.totalCupCents),
      change: Money(sale.changeCents, sale.changeCurrency ?? Currency.cup),
      status: sale.status,
      voidReason: sale.voidReason,
    );
  }

  @override
  Stream<List<SaleReceipt>> watchSessionSales(String sessionId) {
    final query =
        _db.select(_db.sales).join([
            innerJoin(_db.users, _db.users.id.equalsExp(_db.sales.cashierId)),
          ])
          ..where(_db.sales.sessionId.equals(sessionId))
          ..orderBy([OrderingTerm.desc(_db.sales.createdAt)]);
    return query.watch().asyncMap(
      (rows) => Future.wait(
        rows.map(
          (r) =>
              _toReceipt(r.readTable(_db.sales), r.readTable(_db.users).name),
        ),
      ),
    );
  }
}
