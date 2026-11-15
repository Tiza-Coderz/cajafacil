import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:cajafacil/features/products/domain/services/product_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cupPrice', () {
    test('automático: USD x tasa, redondeado a 5 CUP', () {
      // 2.20 USD x 440 = 968 CUP -> 970
      expect(
        ProductPricing.cupPrice(
          priceUsd: const Money.usd(220),
          mode: CupPriceMode.auto,
          rate: ExchangeRate.units(440),
          rounding: CupRounding.five,
        ),
        const Money.cup(97000),
      );
    });

    test('automático sin tasa devuelve null', () {
      expect(
        ProductPricing.cupPrice(
          priceUsd: const Money.usd(220),
          mode: CupPriceMode.auto,
          rounding: CupRounding.five,
        ),
        isNull,
      );
    });

    test('manual ignora la tasa', () {
      expect(
        ProductPricing.cupPrice(
          priceUsd: const Money.usd(30),
          mode: CupPriceMode.manual,
          manualPriceCup: const Money.cup(12000),
          rate: ExchangeRate.units(440),
          rounding: CupRounding.five,
        ),
        const Money.cup(12000),
      );
    });
  });

  group('margen', () {
    test('margen sobre precio en puntos básicos', () {
      expect(
        ProductPricing.marginBasisPoints(
          cost: const Money.usd(160),
          price: const Money.usd(220),
        ),
        2727,
      );
    });

    test('precio cero no divide por cero', () {
      expect(
        ProductPricing.marginBasisPoints(
          cost: const Money.usd(100),
          price: const Money.usd(0),
        ),
        0,
      );
    });

    test('priceForMargin es el inverso', () {
      final price = ProductPricing.priceForMargin(
        cost: const Money.usd(150),
        marginBp: 2500,
      );
      expect(price, const Money.usd(200));
    });
  });

  group('ProductValidator', () {
    ProductDraft draft({
      String name = 'Arroz 1 kg',
      int price = 220,
      CupPriceMode mode = CupPriceMode.auto,
      Money? manual,
      String? barcode,
    }) => ProductDraft(
      name: name,
      unit: ProductUnit.pack,
      costUsd: const Money.usd(160),
      priceUsd: Money.usd(price),
      cupPriceMode: mode,
      manualPriceCup: manual,
      minStockMilli: 0,
      barcode: barcode,
    );

    test('un borrador correcto no tiene errores', () {
      expect(ProductValidator.validate(draft()), isEmpty);
    });

    test('exige nombre y precio positivo', () {
      final errors = ProductValidator.validate(draft(name: ' ', price: 0));
      expect(
        errors.keys,
        containsAll([ProductField.name, ProductField.priceUsd]),
      );
    });

    test('modo manual exige precio CUP', () {
      expect(
        ProductValidator.validate(draft(mode: CupPriceMode.manual)).keys,
        contains(ProductField.manualPriceCup),
      );
    });

    test('valida el formato del código de barras', () {
      expect(
        ProductValidator.validate(draft(barcode: '12')).keys,
        contains(ProductField.barcode),
      );
      expect(
        ProductValidator.validate(draft(barcode: '8501234000017')),
        isEmpty,
      );
    });
  });
}
