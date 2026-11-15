/// Aritmética entera para dinero. Nunca se usa `double` para importes.
library;

/// Divide [numerator] entre [denominator] redondeando la mitad
/// "lejos de cero" (0,5 -> 1 ; -0,5 -> -1), el redondeo comercial habitual.
int divRoundHalfUp(int numerator, int denominator) {
  if (denominator == 0) {
    throw ArgumentError.value(denominator, 'denominator', 'no puede ser 0');
  }
  final negative = (numerator < 0) != (denominator < 0);
  final n = numerator.abs();
  final d = denominator.abs();
  final q = (n * 2 + d) ~/ (d * 2);
  return negative ? -q : q;
}
