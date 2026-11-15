import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/int_math.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:meta/meta.dart';

/// Rango de fechas de un reporte: [from] inclusive, [to] exclusivo.
@immutable
class ReportRange {
  const ReportRange(this.from, this.to, this.label);

  /// Días completos desde las 00:00 de [start] hasta el final de [end].
  factory ReportRange.days(DateTime start, DateTime end, String label) =>
      ReportRange(
        DateTime(start.year, start.month, start.day),
        DateTime(end.year, end.month, end.day).add(const Duration(days: 1)),
        label,
      );

  factory ReportRange.today(DateTime now) => ReportRange.days(now, now, 'Hoy');

  factory ReportRange.lastDays(DateTime now, int days) => ReportRange.days(
    now.subtract(Duration(days: days - 1)),
    now,
    'Últimos $days días',
  );

  factory ReportRange.thisMonth(DateTime now) =>
      ReportRange.days(DateTime(now.year, now.month), now, 'Este mes');

  final DateTime from;
  final DateTime to;
  final String label;

  int get dayCount => to.difference(from).inDays;

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

@immutable
class SalesSummary {
  const SalesSummary({
    required this.salesCount,
    required this.totalUsd,
    required this.totalCup,
    required this.costUsd,
    required this.discountUsd,
    required this.voidedCount,
  });

  static const empty = SalesSummary(
    salesCount: 0,
    totalUsd: Money.usd(0),
    totalCup: Money.cup(0),
    costUsd: Money.usd(0),
    discountUsd: Money.usd(0),
    voidedCount: 0,
  );

  final int salesCount;
  final Money totalUsd;
  final Money totalCup;
  final Money costUsd;
  final Money discountUsd;
  final int voidedCount;

  Money get grossProfitUsd => totalUsd - costUsd;

  /// Margen bruto en puntos básicos.
  int get marginBasisPoints => totalUsd.cents <= 0
      ? 0
      : divRoundHalfUp(grossProfitUsd.cents * 10000, totalUsd.cents);

  Money get averageTicketUsd => salesCount == 0
      ? const Money.usd(0)
      : Money.usd(divRoundHalfUp(totalUsd.cents, salesCount));

  Money get averageTicketCup => salesCount == 0
      ? const Money.cup(0)
      : Money.cup(divRoundHalfUp(totalCup.cents, salesCount));
}

@immutable
class DailySales {
  const DailySales({
    required this.day,
    required this.salesCount,
    required this.totalUsd,
    required this.totalCup,
    required this.costUsd,
  });

  final DateTime day;
  final int salesCount;
  final Money totalUsd;
  final Money totalCup;
  final Money costUsd;

  Money get grossProfitUsd => totalUsd - costUsd;
}

@immutable
class ProductSales {
  const ProductSales({
    required this.productId,
    required this.name,
    required this.unit,
    required this.qtyMilli,
    required this.totalUsd,
    required this.totalCup,
    required this.costUsd,
  });

  final String productId;
  final String name;
  final ProductUnit unit;
  final int qtyMilli;
  final Money totalUsd;
  final Money totalCup;
  final Money costUsd;

  Money get grossProfitUsd => totalUsd - costUsd;
}

@immutable
class CashierSales {
  const CashierSales({
    required this.cashierName,
    required this.salesCount,
    required this.totalUsd,
    required this.totalCup,
  });

  final String cashierName;
  final int salesCount;
  final Money totalUsd;
  final Money totalCup;
}

@immutable
class PaymentMethodTotal {
  const PaymentMethodTotal({required this.method, required this.amount});

  final PaymentMethod method;
  final Money amount;
}

@immutable
class LowStockItem {
  const LowStockItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.stockMilli,
    required this.minStockMilli,
  });

  final String productId;
  final String name;
  final ProductUnit unit;
  final int stockMilli;
  final int minStockMilli;

  /// Cantidad sugerida para volver al doble del mínimo.
  int get suggestedOrderMilli {
    final target = minStockMilli * 2 - stockMilli;
    return target > 0 ? target : 0;
  }
}

/// Reporte completo de un rango, calculado de una vez.
@immutable
class SalesReport {
  const SalesReport({
    required this.range,
    required this.summary,
    required this.daily,
    required this.byProduct,
    required this.byCashier,
    required this.byPaymentMethod,
    required this.lowStock,
  });

  final ReportRange range;
  final SalesSummary summary;
  final List<DailySales> daily;

  /// Ordenado por importe vendido (mayor primero).
  final List<ProductSales> byProduct;
  final List<CashierSales> byCashier;
  final List<PaymentMethodTotal> byPaymentMethod;
  final List<LowStockItem> lowStock;

  List<ProductSales> get top10 => byProduct.take(10).toList();
}
