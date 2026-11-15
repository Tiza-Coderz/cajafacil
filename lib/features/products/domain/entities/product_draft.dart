import 'dart:typed_data';

import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_draft.freezed.dart';

/// Datos editables de un producto (alta o edición).
///
/// La existencia no se edita aquí: solo se fija al crear (`initialStockMilli`)
/// y después cambia por entradas, ajustes o ventas, quedando en el kardex.
@freezed
abstract class ProductDraft with _$ProductDraft {
  const factory ProductDraft({
    required String name,
    required ProductUnit unit,
    required Money costUsd,
    required Money priceUsd,
    required CupPriceMode cupPriceMode,
    required int minStockMilli,
    String? id,
    String? categoryId,
    String? barcode,
    Uint8List? photo,
    Money? manualPriceCup,
    @Default(0) int initialStockMilli,
    @Default(true) bool active,
  }) = _ProductDraft;
}

enum ProductField { name, barcode, costUsd, priceUsd, manualPriceCup, stock }

/// Validación de negocio; devuelve un mensaje por campo con error.
abstract final class ProductValidator {
  static Map<ProductField, String> validate(ProductDraft draft) {
    final errors = <ProductField, String>{};
    final name = draft.name.trim();
    if (name.isEmpty) {
      errors[ProductField.name] = 'Escriba el nombre del producto';
    } else if (name.length > 80) {
      errors[ProductField.name] = 'Máximo 80 caracteres';
    }

    final barcode = draft.barcode?.trim() ?? '';
    if (barcode.isNotEmpty &&
        !RegExp(r'^[0-9A-Za-z-]{4,32}$').hasMatch(barcode)) {
      errors[ProductField.barcode] = 'Código no válido (4 a 32 caracteres)';
    }

    if (draft.costUsd.isNegative) {
      errors[ProductField.costUsd] = 'El costo no puede ser negativo';
    }
    if (!draft.priceUsd.isPositive) {
      errors[ProductField.priceUsd] = 'El precio debe ser mayor que 0';
    }

    if (draft.cupPriceMode == CupPriceMode.manual &&
        !(draft.manualPriceCup?.isPositive ?? false)) {
      errors[ProductField.manualPriceCup] = 'Escriba el precio en CUP';
    }

    if (draft.initialStockMilli < 0 || draft.minStockMilli < 0) {
      errors[ProductField.stock] = 'Las cantidades no pueden ser negativas';
    }
    return errors;
  }
}
