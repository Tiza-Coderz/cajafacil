import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/entities/discount.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

final rate = ExchangeRate.units(440);

CartLine line({
  String id = 'p',
  int qtyMilli = 1000,
  int usd = 220,
  int? cup,
  int cost = 160,
  ProductUnit unit = ProductUnit.unit,
  Discount? discount,
}) => CartLine(
  productId: id,
  name: id,
  unit: unit,
  qtyMilli: qtyMilli,
  unitPriceUsd: Money.usd(usd),
  unitPriceCup: Money.cup(cup ?? usd * 440),
  unitCostUsd: Money.usd(cost),
  discount: discount,
);

SaleTotals totals(
  List<CartLine> lines, {
  Discount? global,
  CupRounding rounding = CupRounding.none,
}) => SaleCalculator.totals(
  lines: lines,
  rate: rate,
  rounding: rounding,
  globalDiscount: global,
);

void main() {
  group('totales', () {
    test('carrito vacío da cero', () {
      final t = totals([]);
      expect(t.isEmpty, isTrue);
      expect(t.totalUsd, const Money.usd(0));
      expect(t.totalCup, const Money.cup(0));
    });

    test('suma líneas con cantidad en ambas monedas', () {
      // 3 x Arroz 2.20 USD / 968 CUP + 2 x Malta 0.85 USD / 374 CUP
      final t = totals([
        line(id: 'arroz', qtyMilli: 3000),
        line(id: 'malta', qtyMilli: 2000, usd: 85, cost: 55),
      ]);
      expect(t.totalUsd, const Money.usd(830));
      expect(t.totalCup, const Money.cup(365200));
      expect(t.costUsd, const Money.usd(590));
      expect(t.grossProfitUsd, const Money.usd(240));
    });

    test('cantidades fraccionarias (1,5 lb de pollo)', () {
      final t = totals([
        line(qtyMilli: 1500, usd: 150, cup: 66000, unit: ProductUnit.pound),
      ]);
      expect(t.totalUsd, const Money.usd(225));
      expect(t.totalCup, const Money.cup(99000));
    });

    test('respeta el precio fijo en CUP de la línea', () {
      // Refresco instantáneo: 0.30 USD pero 120 CUP fijos (no 132).
      final t = totals([line(usd: 30, cup: 12000, qtyMilli: 2000)]);
      expect(t.totalCup, const Money.cup(24000));
      expect(t.totalUsd, const Money.usd(60));
    });

    test('redondea solo el total en CUP según el negocio', () {
      final t = totals([
        line(usd: 95, cup: 41800),
      ], rounding: CupRounding.five);
      expect(t.totalCup, const Money.cup(42000));
      expect(t.totalUsd, const Money.usd(95));
    });
  });

  group('descuentos', () {
    test('por línea en porcentaje', () {
      final t = totals([
        line(qtyMilli: 2000, discount: const Discount.percent(1000)),
      ]);
      // 2 x 2.20 = 4.40 − 10 % = 3.96 ; 1936 CUP − 10 % = 1742.40
      expect(t.lines.single.discountUsd, const Money.usd(44));
      expect(t.totalUsd, const Money.usd(396));
      expect(t.totalCup, const Money.cup(174240));
    });

    test('por línea en importe fijo (USD convertido a CUP)', () {
      final t = totals([line(discount: const Discount.amountUsd(20))]);
      expect(t.totalUsd, const Money.usd(200));
      expect(t.totalCup, const Money.cup(96800 - 8800));
    });

    test('un descuento nunca deja la línea en negativo', () {
      final t = totals([line(discount: const Discount.amountUsd(99999))]);
      expect(t.totalUsd, const Money.usd(0));
      expect(t.totalCup, const Money.cup(0));
    });

    test('descuento global sobre el subtotal ya descontado', () {
      final t = totals(
        [
          line(qtyMilli: 2000, discount: const Discount.percent(1000)),
          line(id: 'b', usd: 100, cup: 44000),
        ],
        global: const Discount.percent(500),
      );
      // Subtotal USD: 3.96 + 1.00 = 4.96 ; global 5 % = 0.25 -> 4.71
      expect(t.subtotalUsd, const Money.usd(496));
      expect(t.globalDiscountUsd, const Money.usd(25));
      expect(t.totalUsd, const Money.usd(471));
      expect(t.totalDiscountUsd, const Money.usd(44 + 25));
    });

    test('porcentaje mayor que 100 se limita a 100', () {
      final t = totals([line()], global: const Discount.percent(20000));
      expect(t.totalUsd, const Money.usd(0));
    });
  });

  test('Discount.describe', () {
    expect(const Discount.percent(1000).describe(), '10 %');
    expect(const Discount.percent(1250).describe(), '12.5 %');
    expect(const Discount.amountUsd(150).describe(), '1.50 USD');
  });

  test('las monedas de los totales son las esperadas', () {
    final t = totals([line()]);
    expect(t.totalUsd.currency, Currency.usd);
    expect(t.totalCup.currency, Currency.cup);
  });
}
