import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:meta/meta.dart';

/// Descuento por porcentaje o por importe fijo.
///
/// - `percent`: [value] en puntos básicos (10 % = 1000).
/// - `amount`: [value] en centavos de **USD**, la moneda base. La UI acepta
///   el importe en CUP y lo convierte con la tasa de la venta.
@immutable
class Discount {
  const Discount.percent(int basisPoints)
    : type = DiscountType.percent,
      value = basisPoints;

  const Discount.amountUsd(int usdCents)
    : type = DiscountType.amount,
      value = usdCents;

  factory Discount.fromStored(DiscountType type, int value) =>
      type == DiscountType.percent
      ? Discount.percent(value)
      : Discount.amountUsd(value);

  final DiscountType type;
  final int value;

  bool get isNone => value <= 0;

  /// Importe a descontar de [gross] (nunca mayor que [gross]).
  /// [rate] convierte el descuento fijo (USD) cuando [gross] está en CUP.
  Money applyTo(Money gross, {required ExchangeRate rate}) {
    if (isNone || !gross.isPositive) return Money.zero(gross.currency);
    final discount = switch (type) {
      DiscountType.percent => gross.percent(value.clamp(0, 10000)),
      DiscountType.amount =>
        gross.currency == Currency.usd
            ? Money.usd(value)
            : rate.toCup(Money.usd(value)),
    };
    return discount > gross ? gross : discount;
  }

  String describe() => switch (type) {
    DiscountType.percent =>
      '${(value / 100).toStringAsFixed(value % 100 == 0 ? 0 : 1)} %',
    DiscountType.amount => '${(value / 100).toStringAsFixed(2)} USD',
  };

  @override
  bool operator ==(Object other) =>
      other is Discount && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}
