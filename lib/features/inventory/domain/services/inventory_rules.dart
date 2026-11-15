import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/int_math.dart';
import 'package:cajafacil/core/money/money.dart';

/// Reglas de inventario en Dart puro.
abstract final class InventoryRules {
  /// Costo promedio ponderado tras una entrada de mercancía.
  ///
  /// `(stock × costo actual + entrada × costo entrada) / (stock + entrada)`.
  /// Si la existencia actual es cero o negativa, el nuevo costo es el de la
  /// entrada (el stock negativo no debe "contaminar" el promedio).
  static Money weightedAverageCost({
    required int stockMilli,
    required Money currentCost,
    required int incomingMilli,
    required Money incomingCost,
  }) {
    if (incomingMilli <= 0) return currentCost;
    if (stockMilli <= 0) return incomingCost;
    final total =
        stockMilli * currentCost.cents + incomingMilli * incomingCost.cents;
    return Money(
      divRoundHalfUp(total, stockMilli + incomingMilli),
      currentCost.currency,
    );
  }

  /// Variación de existencia de un ajuste.
  ///
  /// - Conteo físico: [quantityMilli] es lo contado; la diferencia puede
  ///   ser positiva o negativa.
  /// - Merma, rotura, consumo o robo: [quantityMilli] es lo que se pierde
  ///   y siempre resta.
  static int adjustmentDelta({
    required AdjustmentReason reason,
    required int quantityMilli,
    required int currentStockMilli,
  }) {
    if (quantityMilli < 0) {
      throw ArgumentError.value(quantityMilli, 'quantityMilli', 'negativa');
    }
    return reason == AdjustmentReason.recount
        ? quantityMilli - currentStockMilli
        : -quantityMilli;
  }

  /// Costo total de una entrada.
  static Money purchaseTotal(Iterable<(int qtyMilli, Money unitCost)> items) =>
      items.fold(
        const Money.usd(0),
        (sum, item) => sum + item.$2.timesQty(item.$1),
      );
}
