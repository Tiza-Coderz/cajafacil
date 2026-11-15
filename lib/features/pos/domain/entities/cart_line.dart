import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/pos/domain/entities/discount.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_line.freezed.dart';

/// Línea del carrito. Los precios se congelan al añadir el producto
/// (USD y CUP), así un cambio de tasa no altera una venta en curso.
@freezed
abstract class CartLine with _$CartLine {
  const factory CartLine({
    required String productId,
    required String name,
    required ProductUnit unit,
    required int qtyMilli,
    required Money unitPriceUsd,
    required Money unitPriceCup,
    required Money unitCostUsd,
    Discount? discount,
  }) = _CartLine;
}
