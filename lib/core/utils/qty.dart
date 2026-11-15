import 'package:cajafacil/core/domain/enums.dart';

/// Cantidades en milésimas de la unidad (1,5 lb = 1500) para evitar
/// decimales flotantes en existencias y ventas a granel.
abstract final class Qty {
  static const one = 1000;

  static int units(num value) => (value * one).round();

  /// "12 u", "1.5 lb", "0.25 kg" (sin ceros sobrantes).
  static String format(int milli, ProductUnit unit) =>
      '${formatNumber(milli)} ${unit.symbol}';

  static String formatNumber(int milli) {
    final negative = milli < 0;
    final abs = milli.abs();
    final whole = abs ~/ one;
    final fraction = abs % one;
    final text = fraction == 0
        ? '$whole'
        : '$whole.${fraction.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
    return negative ? '-$text' : text;
  }

  /// Parsea "2", "1,5", "0.250". Devuelve null si no es válido o si la
  /// unidad no admite fracciones y se escribió una.
  static int? parse(String input, {required bool allowFraction}) {
    final cleaned = input.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(cleaned);
    if (match == null) return null;
    final fraction = match.group(2);
    if (!allowFraction && fraction != null && int.parse(fraction) != 0) {
      return null;
    }
    final whole = int.parse(match.group(1)!);
    final milli = int.parse((fraction ?? '').padRight(3, '0'));
    return whole * one + milli;
  }
}
