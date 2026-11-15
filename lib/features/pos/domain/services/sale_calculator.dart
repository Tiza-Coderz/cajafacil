import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/entities/discount.dart';
import 'package:meta/meta.dart';

/// Totales de una línea en ambas monedas.
@immutable
class LineTotals {
  const LineTotals({
    required this.grossUsd,
    required this.grossCup,
    required this.discountUsd,
    required this.discountCup,
    required this.costUsd,
  });

  final Money grossUsd;
  final Money grossCup;
  final Money discountUsd;
  final Money discountCup;
  final Money costUsd;

  Money get totalUsd => grossUsd - discountUsd;
  Money get totalCup => grossCup - discountCup;
}

/// Totales de la venta. USD es la moneda base; CUP se redondea al final
/// según la configuración del negocio.
@immutable
class SaleTotals {
  const SaleTotals({
    required this.lines,
    required this.subtotalUsd,
    required this.subtotalCup,
    required this.globalDiscountUsd,
    required this.globalDiscountCup,
    required this.totalUsd,
    required this.totalCup,
    required this.costUsd,
  });

  final List<LineTotals> lines;

  /// Suma de líneas ya con sus descuentos.
  final Money subtotalUsd;
  final Money subtotalCup;
  final Money globalDiscountUsd;
  final Money globalDiscountCup;
  final Money totalUsd;

  /// Total en CUP ya redondeado.
  final Money totalCup;
  final Money costUsd;

  /// Descuento total (líneas + global) en USD, para reportes.
  Money get totalDiscountUsd =>
      lines.map((l) => l.discountUsd).sum(Currency.usd) + globalDiscountUsd;

  /// Ganancia bruta estimada en USD.
  Money get grossProfitUsd => totalUsd - costUsd;

  bool get isEmpty => lines.isEmpty;
}

abstract final class SaleCalculator {
  static LineTotals line(CartLine line, ExchangeRate rate) {
    final grossUsd = line.unitPriceUsd.timesQty(line.qtyMilli);
    final grossCup = line.unitPriceCup.timesQty(line.qtyMilli);
    final discount = line.discount;
    return LineTotals(
      grossUsd: grossUsd,
      grossCup: grossCup,
      discountUsd:
          discount?.applyTo(grossUsd, rate: rate) ?? const Money.usd(0),
      discountCup:
          discount?.applyTo(grossCup, rate: rate) ?? const Money.cup(0),
      costUsd: line.unitCostUsd.timesQty(line.qtyMilli),
    );
  }

  static SaleTotals totals({
    required List<CartLine> lines,
    required ExchangeRate rate,
    required CupRounding rounding,
    Discount? globalDiscount,
  }) {
    final lineTotals = [for (final l in lines) line(l, rate)];
    final subtotalUsd = lineTotals.map((l) => l.totalUsd).sum(Currency.usd);
    final subtotalCup = lineTotals.map((l) => l.totalCup).sum(Currency.cup);
    final globalUsd =
        globalDiscount?.applyTo(subtotalUsd, rate: rate) ?? const Money.usd(0);
    final globalCup =
        globalDiscount?.applyTo(subtotalCup, rate: rate) ?? const Money.cup(0);

    return SaleTotals(
      lines: lineTotals,
      subtotalUsd: subtotalUsd,
      subtotalCup: subtotalCup,
      globalDiscountUsd: globalUsd,
      globalDiscountCup: globalCup,
      totalUsd: subtotalUsd - globalUsd,
      totalCup: (subtotalCup - globalCup).roundCup(rounding),
      costUsd: lineTotals.map((l) => l.costUsd).sum(Currency.usd),
    );
  }
}
