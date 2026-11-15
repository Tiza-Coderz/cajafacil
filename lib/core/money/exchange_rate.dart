import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/int_math.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:meta/meta.dart';

/// Tasa USD -> CUP. Se guarda como CUP x 100 por 1 USD
/// (ej. `39000` = 390,00 CUP por dólar) para evitar decimales flotantes.
@immutable
class ExchangeRate {
  const ExchangeRate(this.cupPerUsdX100)
    : assert(cupPerUsdX100 > 0, 'La tasa debe ser mayor que cero');

  factory ExchangeRate.units(int cupPerUsd) => ExchangeRate(cupPerUsd * 100);

  final int cupPerUsdX100;

  Money toCup(Money usd) {
    if (usd.currency == Currency.cup) return usd;
    return Money.cup(divRoundHalfUp(usd.cents * cupPerUsdX100, 100));
  }

  Money toUsd(Money cup) {
    if (cup.currency == Currency.usd) return cup;
    return Money.usd(divRoundHalfUp(cup.cents * 100, cupPerUsdX100));
  }

  Money convert(Money money, Currency to) =>
      to == Currency.usd ? toUsd(money) : toCup(money);

  @override
  bool operator ==(Object other) =>
      other is ExchangeRate && other.cupPerUsdX100 == cupPerUsdX100;

  @override
  int get hashCode => cupPerUsdX100.hashCode;

  @override
  String toString() => '1 USD = ${cupPerUsdX100 ~/ 100} CUP';
}
