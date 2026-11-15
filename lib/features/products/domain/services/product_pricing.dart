import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/int_math.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';

/// Reglas de precio de un producto. El precio base siempre es USD.
abstract final class ProductPricing {
  static Money? cupPrice({
    required Money priceUsd,
    required CupPriceMode mode,
    required CupRounding rounding,
    Money? manualPriceCup,
    ExchangeRate? rate,
  }) {
    if (mode == CupPriceMode.manual) return manualPriceCup;
    if (rate == null) return null;
    return rate.toCup(priceUsd).roundCup(rounding);
  }

  /// Margen sobre el precio de venta en puntos básicos (25 % = 2500).
  static int marginBasisPoints({required Money cost, required Money price}) {
    if (price.cents <= 0) return 0;
    return divRoundHalfUp((price.cents - cost.cents) * 10000, price.cents);
  }

  /// Precio sugerido para alcanzar un margen dado sobre el precio.
  static Money priceForMargin({required Money cost, required int marginBp}) {
    if (marginBp >= 10000) {
      throw ArgumentError.value(marginBp, 'marginBp', 'debe ser < 100 %');
    }
    return Money(
      divRoundHalfUp(cost.cents * 10000, 10000 - marginBp),
      cost.currency,
    );
  }
}
