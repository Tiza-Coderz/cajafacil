import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rate_entry.freezed.dart';

/// Una tasa USD→CUP fijada en una fecha, con quién la fijó.
@freezed
abstract class RateEntry with _$RateEntry {
  const factory RateEntry({
    required String id,
    required ExchangeRate rate,
    required DateTime effectiveDate,
    required DateTime createdAt,
    required String createdByName,
    String? note,
  }) = _RateEntry;
}
