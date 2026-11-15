import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/int_math.dart';
import 'package:cajafacil/core/money/money.dart';

/// En la práctica casi no circulan monedas de CUP, por lo que los importes
/// en CUP se redondean a 1, 5 o 10 pesos según la configuración del negocio.
enum CupRounding {
  none(1, 0),
  one(100, 1),
  five(500, 5),
  ten(1000, 10);

  const CupRounding(this.stepCents, this.pesos);

  final int stepCents;
  final int pesos;

  static CupRounding fromPesos(int pesos) =>
      values.firstWhere((r) => r.pesos == pesos, orElse: () => one);
}

extension MoneyRounding on Money {
  /// Redondea al múltiplo más cercano (la mitad hacia arriba). No afecta USD.
  Money roundCup(CupRounding rounding) {
    if (currency != Currency.cup || rounding == CupRounding.none) return this;
    final step = rounding.stepCents;
    return Money(divRoundHalfUp(cents, step) * step, currency);
  }

  /// Redondea hacia abajo: se usa para el vuelto (nunca entregar de más).
  Money floorCup(CupRounding rounding) {
    if (currency != Currency.cup || rounding == CupRounding.none) return this;
    final step = rounding.stepCents;
    return Money((cents ~/ step) * step, currency);
  }
}
