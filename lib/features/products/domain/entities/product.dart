import 'dart:typed_data';

import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/products/domain/services/product_pricing.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    required ProductUnit unit,
    required Money costUsd,
    required Money priceUsd,
    required CupPriceMode cupPriceMode,
    required int stockMilli,
    required int minStockMilli,
    String? categoryId,
    String? categoryName,
    String? barcode,
    Uint8List? photo,
    Money? manualPriceCup,
    @Default(true) bool active,
  }) = _Product;

  const Product._();

  bool get isLowStock => stockMilli <= minStockMilli;

  bool get isOutOfStock => stockMilli <= 0;

  /// Precio en CUP con la tasa del día, o el fijo si es manual.
  /// `null` si es automático y aún no hay tasa.
  Money? priceCup(ExchangeRate? rate, CupRounding rounding) =>
      ProductPricing.cupPrice(
        priceUsd: priceUsd,
        mode: cupPriceMode,
        manualPriceCup: manualPriceCup,
        rate: rate,
        rounding: rounding,
      );

  int get marginBasisPoints =>
      ProductPricing.marginBasisPoints(cost: costUsd, price: priceUsd);
}

@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required String iconKey,
    required int color,
  }) = _Category;
}
