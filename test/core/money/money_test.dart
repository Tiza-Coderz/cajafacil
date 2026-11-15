import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/int_math.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('divRoundHalfUp', () {
    test('redondea la mitad lejos de cero', () {
      expect(divRoundHalfUp(5, 10), 1);
      expect(divRoundHalfUp(4, 10), 0);
      expect(divRoundHalfUp(-5, 10), -1);
      expect(divRoundHalfUp(15, 10), 2);
      expect(divRoundHalfUp(14, 10), 1);
    });

    test('lanza error al dividir por cero', () {
      expect(() => divRoundHalfUp(1, 0), throwsArgumentError);
    });
  });

  group('Money', () {
    test('suma y resta en la misma moneda', () {
      expect(const Money.usd(150) + const Money.usd(250), const Money.usd(400));
      expect(
        const Money.cup(1000) - const Money.cup(250),
        const Money.cup(750),
      );
    });

    test('no permite mezclar monedas sin convertir', () {
      expect(
        () => const Money.usd(100) + const Money.cup(100),
        throwsArgumentError,
      );
    });

    test('multiplica por cantidades fraccionarias (1,5 lb)', () {
      // Pollo a 2.35 USD/lb x 1.5 lb = 3.525 -> 3.53
      expect(const Money.usd(235).timesQty(1500), const Money.usd(353));
      expect(const Money.usd(120).timesQty(3000), const Money.usd(360));
    });

    test('calcula porcentajes en puntos básicos', () {
      expect(const Money.usd(1000).percent(1000), const Money.usd(100));
      expect(const Money.usd(333).percent(1500), const Money.usd(50));
    });

    test('tryParse acepta coma, punto y espacios', () {
      expect(Money.tryParse('12.5', Currency.usd), const Money.usd(1250));
      expect(Money.tryParse('12,50', Currency.usd), const Money.usd(1250));
      expect(Money.tryParse('1 250', Currency.cup), const Money.cup(125000));
      expect(Money.tryParse('abc', Currency.cup), isNull);
      expect(Money.tryParse('1.234', Currency.cup), isNull);
    });

    test('sum de una lista vacía es cero', () {
      expect(<Money>[].sum(Currency.cup), const Money.zero(Currency.cup));
    });
  });

  group('ExchangeRate', () {
    const rate = ExchangeRate(39000); // 390 CUP por USD

    test('convierte USD a CUP', () {
      expect(rate.toCup(const Money.usd(250)), const Money.cup(97500));
    });

    test('convierte CUP a USD con redondeo', () {
      // 1000 CUP / 390 = 2.5641 -> 2.56
      expect(rate.toUsd(const Money.cup(100000)), const Money.usd(256));
    });

    test('convertir a la misma moneda no cambia nada', () {
      expect(
        rate.convert(const Money.usd(5), Currency.usd),
        const Money.usd(5),
      );
    });
  });

  group('CupRounding', () {
    test('roundCup redondea al múltiplo más cercano', () {
      expect(
        const Money.cup(97249).roundCup(CupRounding.five),
        const Money.cup(97000),
      );
      expect(
        const Money.cup(97250).roundCup(CupRounding.five),
        const Money.cup(97500),
      );
      expect(
        const Money.cup(12345).roundCup(CupRounding.one),
        const Money.cup(12300),
      );
    });

    test('floorCup siempre baja (vuelto)', () {
      expect(
        const Money.cup(97499).floorCup(CupRounding.five),
        const Money.cup(97000),
      );
    });

    test('no redondea USD', () {
      expect(
        const Money.usd(1999).roundCup(CupRounding.ten),
        const Money.usd(1999),
      );
    });
  });

  group('MoneyFormatter', () {
    test('USD siempre con centavos', () {
      expect(MoneyFormatter.format(const Money.usd(1250)), '12.50 USD');
    });

    test('CUP sin centavos cuando son enteros y con miles', () {
      expect(MoneyFormatter.format(const Money.cup(125000)), '1 250 CUP');
    });

    test('negativos', () {
      expect(MoneyFormatter.format(const Money.usd(-500)), '-5.00 USD');
    });
  });
}
