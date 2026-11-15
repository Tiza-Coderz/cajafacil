import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/inventory/domain/services/inventory_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('costo promedio ponderado', () {
    test('mezcla existencia y entrada según cantidades', () {
      // 10 u a 1.60 + 30 u a 2.00 = (16 + 60) / 40 = 1.90
      expect(
        InventoryRules.weightedAverageCost(
          stockMilli: 10000,
          currentCost: const Money.usd(160),
          incomingMilli: 30000,
          incomingCost: const Money.usd(200),
        ),
        const Money.usd(190),
      );
    });

    test('sin existencia, el costo es el de la entrada', () {
      expect(
        InventoryRules.weightedAverageCost(
          stockMilli: 0,
          currentCost: const Money.usd(160),
          incomingMilli: 5000,
          incomingCost: const Money.usd(210),
        ),
        const Money.usd(210),
      );
    });

    test('existencia negativa no contamina el promedio', () {
      expect(
        InventoryRules.weightedAverageCost(
          stockMilli: -3000,
          currentCost: const Money.usd(100),
          incomingMilli: 5000,
          incomingCost: const Money.usd(150),
        ),
        const Money.usd(150),
      );
    });

    test('funciona con cantidades fraccionarias (libras)', () {
      // 2.5 lb a 1.10 + 7.5 lb a 1.30 = (2.75 + 9.75) / 10 = 1.25
      expect(
        InventoryRules.weightedAverageCost(
          stockMilli: 2500,
          currentCost: const Money.usd(110),
          incomingMilli: 7500,
          incomingCost: const Money.usd(130),
        ),
        const Money.usd(125),
      );
    });
  });

  group('variación de un ajuste', () {
    test('merma, rotura, consumo y robo siempre restan', () {
      for (final r in [
        AdjustmentReason.waste,
        AdjustmentReason.breakage,
        AdjustmentReason.internalUse,
        AdjustmentReason.theft,
      ]) {
        expect(
          InventoryRules.adjustmentDelta(
            reason: r,
            quantityMilli: 2000,
            currentStockMilli: 10000,
          ),
          -2000,
          reason: r.label,
        );
      }
    });

    test('el conteo físico ajusta a lo contado (sube o baja)', () {
      expect(
        InventoryRules.adjustmentDelta(
          reason: AdjustmentReason.recount,
          quantityMilli: 8000,
          currentStockMilli: 10000,
        ),
        -2000,
      );
      expect(
        InventoryRules.adjustmentDelta(
          reason: AdjustmentReason.recount,
          quantityMilli: 12000,
          currentStockMilli: 10000,
        ),
        2000,
      );
    });

    test('rechaza cantidades negativas', () {
      expect(
        () => InventoryRules.adjustmentDelta(
          reason: AdjustmentReason.waste,
          quantityMilli: -1,
          currentStockMilli: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  test('total de una entrada', () {
    expect(
      InventoryRules.purchaseTotal([
        (24000, const Money.usd(65)),
        (2500, const Money.usd(110)),
      ]),
      const Money.usd(1560 + 275),
    );
  });
}
