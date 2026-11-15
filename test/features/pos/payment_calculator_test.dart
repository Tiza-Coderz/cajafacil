import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

final rate = ExchangeRate.units(440);

/// Venta de 9.70 USD / 4 270 CUP (ya redondeado a 5).
SaleTotals sale({int usd = 970, int cup = 426800}) => SaleCalculator.totals(
  lines: [
    CartLine(
      productId: 'p',
      name: 'p',
      unit: ProductUnit.unit,
      qtyMilli: 1000,
      unitPriceUsd: Money.usd(usd),
      unitPriceCup: Money.cup(cup),
      unitCostUsd: const Money.usd(0),
    ),
  ],
  rate: rate,
  rounding: CupRounding.five,
);

PaymentStatus pay(
  List<Payment> payments, {
  Currency change = Currency.cup,
  SaleTotals? totals,
}) => PaymentCalculator.evaluate(
  totals: totals ?? sale(),
  payments: payments,
  rate: rate,
  changeCurrency: change,
  rounding: CupRounding.five,
);

Payment cashCup(int pesos) =>
    Payment(method: PaymentMethod.cashCup, amount: Money.cup(pesos * 100));
Payment cashUsd(int cents) =>
    Payment(method: PaymentMethod.cashUsd, amount: Money.usd(cents));

void main() {
  test('el total en CUP se redondeó a 4 270', () {
    expect(sale().totalCup, const Money.cup(427000));
  });

  group('sin pagos o pago parcial', () {
    test('sin pagos falta todo, en ambas monedas', () {
      final s = pay([]);
      expect(s.isPaid, isFalse);
      expect(s.remainingCup, const Money.cup(427000));
      expect(s.remainingUsd, const Money.usd(970));
    });

    test('pago parcial en CUP: falta el resto, redondeado hacia arriba', () {
      final s = pay([cashCup(2000)]);
      expect(s.remainingCup, const Money.cup(227000));
      // 2 270 / 440 = 5.159 -> 5.16 USD (nunca cobrar de menos)
      expect(s.remainingUsd, const Money.usd(516));
      expect(s.canComplete, isFalse);
    });
  });

  group('vuelto en CUP', () {
    test('paga con 5 000 CUP: vuelto 730 CUP', () {
      final s = pay([cashCup(5000)]);
      expect(s.isPaid, isTrue);
      expect(s.change, const Money.cup(73000));
    });

    test('el vuelto se redondea hacia abajo al múltiplo de 5', () {
      final totals = sale(cup: 426600); // -> 4 265 tras redondeo a 5
      final s = pay([cashCup(4300)], totals: totals);
      expect(totals.totalCup, const Money.cup(426500));
      expect(s.change, const Money.cup(3500));
    });

    test('paga en USD y pide vuelto en CUP', () {
      // Solo USD: se liquida contra el total USD (9.70). Paga 20 USD.
      // Vuelto 10.30 USD -> 4 532 CUP -> 4 530 (abajo, múltiplo de 5).
      final s = pay([cashUsd(2000)]);
      expect(s.change, const Money.cup(453000));
    });
  });

  group('vuelto en USD', () {
    test('todo en USD: vuelto exacto en USD', () {
      final s = pay([cashUsd(2000)], change: Currency.usd);
      expect(s.change, const Money.usd(1030));
    });

    test('pago en CUP con vuelto en USD: se trunca a centavos', () {
      // Paga 10 000 CUP: sobran 5 730 CUP -> 13.0227 USD -> 13.02
      final s = pay([cashCup(10000)], change: Currency.usd);
      expect(s.change, const Money.usd(1302));
    });
  });

  group('pago mixto', () {
    // Caso real visto en la demo: 7.73 USD / 3 410 CUP (3 410 / 440 = 7.75,
    // los totales no son conversión exacta uno del otro por redondeos).
    SaleTotals uneven() => sale(usd: 773, cup: 341000);

    test('tras un pago parcial en USD, "exacto en CUP" completa la venta', () {
      // Regresión: lo que falta en CUP se calcula en CUP
      // (3 410 − 5 × 440 = 1 210), no convirtiendo el saldo en USD (1 205).
      final partial = pay([cashUsd(500)], totals: uneven());
      expect(partial.remainingCup, const Money.cup(121000));
      expect(partial.remainingUsd, const Money.usd(273));

      final done = pay([
        cashUsd(500),
        Payment(method: PaymentMethod.cashCup, amount: partial.remainingCup),
      ], totals: uneven());
      expect(done.canComplete, isTrue);
      expect(done.change.isZero, isTrue);
    });

    test('tras un pago parcial en USD, "exacto en USD" también completa', () {
      final partial = pay([cashUsd(500)], totals: uneven());
      final done = pay([
        cashUsd(500),
        cashUsd(partial.remainingUsd.cents),
      ], totals: uneven());
      expect(done.canComplete, isTrue);
    });

    test('USD + CUP se liquida en CUP con la tasa de la venta', () {
      // 5 USD = 2 200 CUP ; + 2 100 CUP = 4 300 ; total 4 270 -> vuelto 30
      final s = pay([cashUsd(500), cashCup(2100)]);
      expect(s.isPaid, isTrue);
      expect(s.change, const Money.cup(3000));
    });

    test('Transfermóvil exacto + efectivo', () {
      final s = pay([
        const Payment(
          method: PaymentMethod.transfermovil,
          amount: Money.cup(300000),
          reference: 'TM12345',
        ),
        cashCup(1500),
      ]);
      expect(s.canComplete, isTrue);
      expect(s.change, const Money.cup(23000));
    });

    test('un pago electrónico mayor que el total se marca para corregir', () {
      final s = pay([
        const Payment(method: PaymentMethod.enzona, amount: Money.cup(500000)),
      ]);
      expect(s.isPaid, isTrue);
      expect(s.overpaidElectronic, isTrue);
      expect(s.canComplete, isFalse);
    });

    test('electrónico exacto se puede completar sin vuelto', () {
      final s = pay([
        const Payment(method: PaymentMethod.enzona, amount: Money.cup(427000)),
      ]);
      expect(s.canComplete, isTrue);
      expect(s.change.isZero, isTrue);
    });
  });

  group('sugerencias de efectivo', () {
    test('billetes redondos por encima de lo que falta', () {
      expect(
        PaymentCalculator.quickCashSuggestions(const Money.cup(427000)),
        const [Money.cup(430000), Money.cup(450000), Money.cup(500000)],
      );
    });

    test('nada que sugerir si no falta nada', () {
      expect(
        PaymentCalculator.quickCashSuggestions(const Money.cup(0)),
        isEmpty,
      );
    });

    test('en USD sugiere billetes de dólar', () {
      expect(
        PaymentCalculator.quickCashSuggestions(const Money.usd(970)),
        const [Money.usd(1000), Money.usd(2000), Money.usd(5000)],
      );
    });
  });
}
