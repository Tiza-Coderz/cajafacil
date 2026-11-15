import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/features/exchange_rate/domain/services/rate_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta enteros y decimales con punto o coma', () {
    expect(
      (RateValidator.validate('440') as RateValid).rate,
      const ExchangeRate(44000),
    );
    expect(
      (RateValidator.validate('437,50') as RateValid).rate,
      const ExchangeRate(43750),
    );
  });

  test('rechaza vacío, texto y valores fuera de rango', () {
    expect(RateValidator.validate(''), isA<RateInvalid>());
    expect(RateValidator.validate('abc'), isA<RateInvalid>());
    expect(RateValidator.validate('0'), isA<RateInvalid>());
    expect(RateValidator.validate('-5'), isA<RateInvalid>());
    expect(RateValidator.validate('9000'), isA<RateInvalid>());
  });

  test('avisa (sin bloquear) ante un cambio de 15 % o más', () {
    final result = RateValidator.validate(
      '520',
      previous: ExchangeRate.units(440),
    );
    expect(result, isA<RateValid>());
    expect((result as RateValid).warning, contains('sube'));
  });

  test('no avisa en cambios pequeños', () {
    final result = RateValidator.validate(
      '445',
      previous: ExchangeRate.units(440),
    );
    expect((result as RateValid).warning, isNull);
  });

  test('changePercent calcula la variación', () {
    expect(
      RateValidator.changePercent(
        ExchangeRate.units(400),
        ExchangeRate.units(420),
      ),
      5,
    );
  });
}
