import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/int_math.dart';
import 'package:meta/meta.dart';

/// Importe monetario inmutable expresado en centavos enteros.
@immutable
class Money implements Comparable<Money> {
  const Money(this.cents, this.currency);

  const Money.zero(this.currency) : cents = 0;

  const Money.usd(this.cents) : currency = Currency.usd;

  const Money.cup(this.cents) : currency = Currency.cup;

  /// Crea un importe desde unidades enteras (ej. `Money.units(390, cup)`).
  factory Money.units(int units, Currency currency) =>
      Money(units * 100, currency);

  final int cents;
  final Currency currency;

  /// Parsea texto escrito por el usuario: "12.5", "12,50", "1 250".
  /// Devuelve `null` si no es un número válido.
  static Money? tryParse(String input, Currency currency) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[\s ]'), '')
        .replaceAll(',', '.');
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;
    final sign = match.group(1) == '-' ? -1 : 1;
    final whole = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    return Money(sign * (whole * 100 + int.parse(fraction)), currency);
  }

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;
  bool get isPositive => cents > 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(cents + other.cents, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(cents - other.cents, currency);
  }

  Money operator -() => Money(-cents, currency);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Multiplica por una cantidad en milésimas (1,5 lb = 1500).
  Money timesQty(int qtyMilli) =>
      Money(divRoundHalfUp(cents * qtyMilli, 1000), currency);

  /// Porcentaje en puntos básicos (10 % = 1000).
  Money percent(int basisPoints) =>
      Money(divRoundHalfUp(cents * basisPoints, 10000), currency);

  Money abs() => isNegative ? -this : this;

  Money clampMin(Money min) => this < min ? min : this;

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return cents.compareTo(other.cents);
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'No se pueden operar ${currency.code} y ${other.currency.code} '
        'sin convertir antes con la tasa de cambio.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.cents == cents && other.currency == currency;

  @override
  int get hashCode => Object.hash(cents, currency);

  @override
  String toString() {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final fraction = (abs % 100).toString().padLeft(2, '0');
    return '$sign${abs ~/ 100}.$fraction ${currency.code}';
  }
}

extension MoneyIterable on Iterable<Money> {
  Money sum(Currency currency) => fold(Money.zero(currency), (a, b) => a + b);
}
