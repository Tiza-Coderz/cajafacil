import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:drift/drift.dart';

/// Consultas agregadas para reportes. Se hacen en SQL (no en memoria) para
/// que escalen a meses de ventas en un teléfono modesto.
class ReportsRepository {
  ReportsRepository(this._db);

  final AppDatabase _db;

  /// Filtro común: ventas cobradas, no borradas, dentro del rango.
  static const _saleFilter =
      "s.status = 'completed' AND s.deleted_at IS NULL "
      'AND s.created_at >= ?1 AND s.created_at < ?2';

  List<Variable<Object>> _rangeVars(ReportRange r) => [
    Variable.withInt(r.from.toUtc().millisecondsSinceEpoch),
    Variable.withInt(r.to.toUtc().millisecondsSinceEpoch),
  ];

  Future<SalesReport> build(ReportRange range) async {
    final results = await Future.wait([
      _summary(range),
      _daily(range),
      _byProduct(range),
      _byCashier(range),
      _byPaymentMethod(range),
      _lowStock(),
    ]);
    return SalesReport(
      range: range,
      summary: results[0] as SalesSummary,
      daily: results[1] as List<DailySales>,
      byProduct: results[2] as List<ProductSales>,
      byCashier: results[3] as List<CashierSales>,
      byPaymentMethod: results[4] as List<PaymentMethodTotal>,
      lowStock: results[5] as List<LowStockItem>,
    );
  }

  Future<SalesSummary> _summary(ReportRange r) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n, '
          'COALESCE(SUM(s.total_usd_cents), 0) AS usd, '
          'COALESCE(SUM(s.total_cup_cents), 0) AS cup, '
          'COALESCE(SUM(s.total_cost_usd_cents), 0) AS cost, '
          'COALESCE(SUM(s.discount_usd_cents), 0) AS disc, '
          "(SELECT COUNT(*) FROM sales v WHERE v.status = 'voided' "
          'AND v.created_at >= ?1 AND v.created_at < ?2) AS voided '
          'FROM sales s WHERE $_saleFilter',
          variables: _rangeVars(r),
          readsFrom: {_db.sales},
        )
        .getSingle();
    return SalesSummary(
      salesCount: row.read<int>('n'),
      totalUsd: Money.usd(row.read<int>('usd')),
      totalCup: Money.cup(row.read<int>('cup')),
      costUsd: Money.usd(row.read<int>('cost')),
      discountUsd: Money.usd(row.read<int>('disc')),
      voidedCount: row.read<int>('voided'),
    );
  }

  Future<List<DailySales>> _daily(ReportRange r) async {
    // SQLite en WASM no conoce la zona horaria: se pasa el desfase local.
    final offsetSeconds = r.from.timeZoneOffset.inSeconds;
    final rows = await _db
        .customSelect(
          "SELECT date(s.created_at / 1000 + ?3, 'unixepoch') AS d, "
          'COUNT(*) AS n, SUM(s.total_usd_cents) AS usd, '
          'SUM(s.total_cup_cents) AS cup, SUM(s.total_cost_usd_cents) AS cost '
          'FROM sales s WHERE $_saleFilter GROUP BY d ORDER BY d',
          variables: [..._rangeVars(r), Variable.withInt(offsetSeconds)],
          readsFrom: {_db.sales},
        )
        .get();
    final byDay = {
      for (final row in rows)
        row.read<String>('d'): DailySales(
          day: DateTime.parse(row.read<String>('d')),
          salesCount: row.read<int>('n'),
          totalUsd: Money.usd(row.read<int>('usd')),
          totalCup: Money.cup(row.read<int>('cup')),
          costUsd: Money.usd(row.read<int>('cost')),
        ),
    };
    // Rellena días sin ventas con cero para que el gráfico no tenga huecos.
    return [
      for (var i = 0; i < r.dayCount; i++)
        () {
          final day = DateTime(r.from.year, r.from.month, r.from.day + i);
          final key =
              '${day.year}-${day.month.toString().padLeft(2, '0')}'
              '-${day.day.toString().padLeft(2, '0')}';
          return byDay[key] ??
              DailySales(
                day: day,
                salesCount: 0,
                totalUsd: const Money.usd(0),
                totalCup: const Money.cup(0),
                costUsd: const Money.usd(0),
              );
        }(),
    ];
  }

  Future<List<ProductSales>> _byProduct(ReportRange r) async {
    final rows = await _db
        .customSelect(
          'SELECT i.product_id AS id, MAX(i.name_snapshot) AS name, '
          'MAX(p.unit) AS unit, SUM(i.qty_milli) AS qty, '
          'SUM(i.line_total_usd_cents) AS usd, '
          'SUM(i.line_total_cup_cents) AS cup, '
          'SUM(ROUND(i.unit_cost_usd_cents * i.qty_milli / 1000.0)) AS cost '
          'FROM sale_items i '
          'JOIN sales s ON s.id = i.sale_id '
          'LEFT JOIN products p ON p.id = i.product_id '
          'WHERE $_saleFilter AND i.deleted_at IS NULL '
          'GROUP BY i.product_id ORDER BY usd DESC',
          variables: _rangeVars(r),
          readsFrom: {_db.sales, _db.saleItems, _db.products},
        )
        .get();
    return [
      for (final row in rows)
        ProductSales(
          productId: row.read<String>('id'),
          name: row.read<String>('name'),
          unit: ProductUnit.values.byName(
            row.readNullable<String>('unit') ?? ProductUnit.unit.name,
          ),
          qtyMilli: row.read<int>('qty'),
          totalUsd: Money.usd(row.read<int>('usd')),
          totalCup: Money.cup(row.read<int>('cup')),
          costUsd: Money.usd(row.read<double>('cost').round()),
        ),
    ];
  }

  Future<List<CashierSales>> _byCashier(ReportRange r) async {
    final rows = await _db
        .customSelect(
          'SELECT u.name AS name, COUNT(*) AS n, '
          'SUM(s.total_usd_cents) AS usd, SUM(s.total_cup_cents) AS cup '
          'FROM sales s JOIN users u ON u.id = s.cashier_id '
          'WHERE $_saleFilter GROUP BY s.cashier_id ORDER BY usd DESC',
          variables: _rangeVars(r),
          readsFrom: {_db.sales, _db.users},
        )
        .get();
    return [
      for (final row in rows)
        CashierSales(
          cashierName: row.read<String>('name'),
          salesCount: row.read<int>('n'),
          totalUsd: Money.usd(row.read<int>('usd')),
          totalCup: Money.cup(row.read<int>('cup')),
        ),
    ];
  }

  Future<List<PaymentMethodTotal>> _byPaymentMethod(ReportRange r) async {
    final rows = await _db
        .customSelect(
          'SELECT p.method AS method, p.currency AS currency, '
          'SUM(p.amount_cents) AS amount '
          'FROM sale_payments p JOIN sales s ON s.id = p.sale_id '
          'WHERE $_saleFilter AND p.deleted_at IS NULL '
          'GROUP BY p.method, p.currency ORDER BY amount DESC',
          variables: _rangeVars(r),
          readsFrom: {_db.sales, _db.salePayments},
        )
        .get();
    return [
      for (final row in rows)
        PaymentMethodTotal(
          method: PaymentMethod.values.byName(row.read<String>('method')),
          amount: Money(
            row.read<int>('amount'),
            Currency.values.byName(row.read<String>('currency')),
          ),
        ),
    ];
  }

  Future<List<LowStockItem>> _lowStock() async {
    final query = _db.select(_db.products)
      ..where(
        (p) =>
            p.deletedAt.isNull() &
            p.active.equals(true) &
            p.stockMilli.isSmallerOrEqual(p.minStockMilli),
      )
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return [
      for (final p in await query.get())
        LowStockItem(
          productId: p.id,
          name: p.name,
          unit: p.unit,
          stockMilli: p.stockMilli,
          minStockMilli: p.minStockMilli,
        ),
    ];
  }
}
