import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_entities.freezed.dart';

@freezed
abstract class Supplier with _$Supplier {
  const factory Supplier({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) = _Supplier;
}

/// Línea de una entrada de mercancía.
@freezed
abstract class PurchaseItemDraft with _$PurchaseItemDraft {
  const factory PurchaseItemDraft({
    required String productId,
    required String productName,
    required ProductUnit unit,
    required int qtyMilli,
    required Money unitCostUsd,
  }) = _PurchaseItemDraft;
}

@freezed
abstract class PurchaseDraft with _$PurchaseDraft {
  const factory PurchaseDraft({
    required List<PurchaseItemDraft> items,
    String? supplierId,
    String? invoiceRef,
    String? note,
    DateTime? date,
  }) = _PurchaseDraft;
}

/// Entrada registrada (para el listado).
@freezed
abstract class PurchaseSummary with _$PurchaseSummary {
  const factory PurchaseSummary({
    required String id,
    required DateTime date,
    required Money totalCostUsd,
    required int itemCount,
    required String userName,
    String? supplierName,
    String? invoiceRef,
  }) = _PurchaseSummary;
}

/// Movimiento del kardex con datos legibles.
@freezed
abstract class KardexEntry with _$KardexEntry {
  const factory KardexEntry({
    required String id,
    required DateTime date,
    required StockMovementType type,
    required int qtyDeltaMilli,
    required int balanceAfterMilli,
    required Money unitCostUsd,
    required String userName,
    AdjustmentReason? reason,
    String? note,
    String? refId,
  }) = _KardexEntry;

  const KardexEntry._();

  String get label => reason?.label ?? type.label;
}
