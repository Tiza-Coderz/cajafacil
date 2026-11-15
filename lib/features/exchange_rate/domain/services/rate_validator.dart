import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';

/// Resultado de validar una tasa escrita por el usuario.
sealed class RateValidation {
  const RateValidation();
}

class RateInvalid extends RateValidation {
  const RateInvalid(this.message);
  final String message;
}

class RateValid extends RateValidation {
  const RateValid(this.rate, {this.warning});
  final ExchangeRate rate;

  /// Aviso no bloqueante (ej. cambio brusco respecto a la tasa anterior).
  final String? warning;
}

/// Reglas de negocio para fijar la tasa del día.
abstract final class RateValidator {
  static const minCupPerUsd = 1;
  static const maxCupPerUsd = 5000;

  /// Variación a partir de la cual se pide confirmación (en %).
  static const bigChangePercent = 15;

  static RateValidation validate(String input, {ExchangeRate? previous}) {
    final parsed = Money.tryParse(input, Currency.cup);
    if (parsed == null || input.trim().isEmpty) {
      return const RateInvalid('Escriba un número, por ejemplo 420 o 420.50');
    }
    final x100 = parsed.cents;
    if (x100 < minCupPerUsd * 100 || x100 > maxCupPerUsd * 100) {
      return const RateInvalid(
        'La tasa debe estar entre $minCupPerUsd y $maxCupPerUsd CUP',
      );
    }
    final rate = ExchangeRate(x100);
    if (previous == null) return RateValid(rate);

    final change = changePercent(previous, rate);
    if (change.abs() >= bigChangePercent) {
      final direction = change > 0 ? 'sube' : 'baja';
      return RateValid(
        rate,
        warning:
            'La tasa $direction un ${change.abs().toStringAsFixed(1)} %. '
            '¿Está seguro?',
      );
    }
    return RateValid(rate);
  }

  /// Variación porcentual de [from] a [to] (para mostrar, no para dinero).
  static double changePercent(ExchangeRate from, ExchangeRate to) =>
      (to.cupPerUsdX100 - from.cupPerUsdX100) * 100 / from.cupPerUsdX100;
}
