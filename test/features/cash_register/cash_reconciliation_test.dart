import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:flutter_test/flutter_test.dart';

CurrencyPair pair(int usdCents, int cupCents) =>
    CurrencyPair(usd: Money.usd(usdCents), cup: Money.cup(cupCents));

void main() {
  group('CashReconciliation.summarize', () {
    test('turno sin ventas: lo esperado es el fondo', () {
      final s = CashReconciliation.summarize(
        opening: pair(2000, 500000),
        payments: const [],
        changes: const [],
        movements: const [],
        salesCount: 0,
      );
      expect(s.expected, pair(2000, 500000));
    });

    test(
      'esperado = fondo + efectivo recibido − vuelto + entradas − salidas',
      () {
        final s = CashReconciliation.summarize(
          opening: pair(2000, 500000), // 20 USD y 5 000 CUP
          payments: const [
            PaymentLine(PaymentMethod.cashCup, Money.cup(200000)), // 2 000 CUP
            PaymentLine(PaymentMethod.cashUsd, Money.usd(1000)), // 10 USD
            PaymentLine(PaymentMethod.cashCup, Money.cup(100000)), // 1 000 CUP
          ],
          changes: const [Money.cup(35000), Money.usd(150)], // vueltos
          movements: const [
            CashMovementLine(CashMovementType.cashIn, Money.cup(50000)),
            CashMovementLine(CashMovementType.cashOut, Money.cup(120000)),
            CashMovementLine(CashMovementType.cashOut, Money.usd(500)),
          ],
          salesCount: 3,
        );

        // CUP: 5000 + 3000 − 350 + 500 − 1200 = 6950
        // USD: 20 + 10 − 1.50 − 5 = 23.50
        expect(s.expected, pair(2350, 695000));
        expect(s.netCashSales, pair(850, 265000));
        expect(s.salesCount, 3);
      },
    );

    test('los pagos electrónicos no cuentan para la gaveta', () {
      final s = CashReconciliation.summarize(
        opening: pair(0, 100000),
        payments: const [
          PaymentLine(PaymentMethod.transfermovil, Money.cup(440000)),
          PaymentLine(PaymentMethod.enzona, Money.cup(97000)),
          PaymentLine(PaymentMethod.transfer, Money.usd(2500)),
          PaymentLine(PaymentMethod.transfermovil, Money.cup(10000)),
        ],
        changes: const [],
        movements: const [],
        salesCount: 3,
      );
      expect(s.expected, pair(0, 100000));
      expect(
        s.electronicByMethod[PaymentMethod.transfermovil],
        pair(0, 450000),
      );
      expect(s.electronicByMethod[PaymentMethod.enzona], pair(0, 97000));
      expect(s.electronicByMethod[PaymentMethod.transfer], pair(2500, 0));
    });

    test('pago mixto: solo la parte en efectivo entra a la gaveta', () {
      // Venta de 2 000 CUP: 1 500 por Transfermóvil + 500 en efectivo CUP.
      final s = CashReconciliation.summarize(
        opening: const CurrencyPair.zero(),
        payments: const [
          PaymentLine(PaymentMethod.transfermovil, Money.cup(150000)),
          PaymentLine(PaymentMethod.cashCup, Money.cup(50000)),
        ],
        changes: const [],
        movements: const [],
        salesCount: 1,
      );
      expect(s.expected, pair(0, 50000));
    });
  });

  group('diferencia de cuadre', () {
    test('cuadra exacto', () {
      expect(
        CashReconciliation.difference(
          counted: pair(2350, 695000),
          expected: pair(2350, 695000),
        ).isZero,
        isTrue,
      );
    });

    test('faltante es negativo y sobrante positivo, por moneda', () {
      final diff = CashReconciliation.difference(
        counted: pair(2400, 690000),
        expected: pair(2350, 695000),
      );
      expect(diff.cup, const Money.cup(-5000)); // faltan 50 CUP
      expect(diff.usd, const Money.usd(50)); // sobran 0.50 USD
    });
  });

  group('Denominations', () {
    test('suma el conteo por billetes', () {
      expect(
        Denominations.total(Currency.cup, {1000: 3, 200: 4, 50: 1, 3: 2}),
        const Money.cup(385600),
      );
      expect(
        Denominations.total(Currency.usd, {20: 1, 1: 3}),
        const Money.usd(2300),
      );
    });

    test('rechaza cantidades negativas', () {
      expect(
        () => Denominations.total(Currency.cup, {100: -1}),
        throwsArgumentError,
      );
    });

    test('incluye el billete de 3 pesos cubano', () {
      expect(Denominations.cup, contains(3));
    });
  });

  test('CurrencyPair no permite monedas cruzadas', () {
    expect(
      () => CurrencyPair(usd: const Money.cup(1), cup: const Money.cup(1)),
      throwsArgumentError,
    );
  });
}
