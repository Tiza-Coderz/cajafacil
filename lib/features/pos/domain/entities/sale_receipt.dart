import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sale_receipt.freezed.dart';

/// Venta registrada, con todo lo necesario para el ticket.
@freezed
abstract class SaleReceipt with _$SaleReceipt {
  const factory SaleReceipt({
    required String id,
    required String number,
    required DateTime createdAt,
    required String cashierName,
    required ExchangeRate rate,
    required List<ReceiptLine> lines,
    required List<Payment> payments,
    required Money subtotalUsd,
    required Money discountUsd,
    required Money totalUsd,
    required Money totalCup,
    required Money change,
    required SaleStatus status,
    String? voidReason,
  }) = _SaleReceipt;

  const SaleReceipt._();

  bool get isVoided => status == SaleStatus.voided;
}

@freezed
abstract class ReceiptLine with _$ReceiptLine {
  const factory ReceiptLine({
    required String name,
    required ProductUnit unit,
    required int qtyMilli,
    required Money unitPriceUsd,
    required Money unitPriceCup,
    required Money discountUsd,
    required Money totalUsd,
    required Money totalCup,
  }) = _ReceiptLine;
}
