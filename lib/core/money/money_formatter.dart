import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';

/// Formato de importes para Cuba: miles separados con espacio fino y punto
/// decimal, como en las tablillas de precios ("1 250 CUP", "12.50 USD").
abstract final class MoneyFormatter {
  /// [decimals]: `null` = automático (USD siempre con centavos; CUP solo si
  /// los tiene).
  static String format(Money money, {bool withCode = true, bool? decimals}) {
    final showDecimals =
        decimals ?? (money.currency == Currency.usd || money.cents % 100 != 0);
    final abs = money.cents.abs();
    final buffer = StringBuffer()
      ..write(money.isNegative ? '-' : '')
      ..write(_groupThousands(abs ~/ 100));
    if (showDecimals) {
      buffer.write('.${(abs % 100).toString().padLeft(2, '0')}');
    }
    if (withCode) buffer.write(' ${money.currency.code}');
    return buffer.toString();
  }

  static String _groupThousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
