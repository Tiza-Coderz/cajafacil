import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/features/exchange_rate/domain/entities/rate_entry.dart';

abstract interface class ExchangeRateRepository {
  /// Tasa vigente (la más reciente), o `null` si nunca se fijó una.
  Stream<RateEntry?> watchCurrent();

  /// Historial más reciente primero.
  Stream<List<RateEntry>> watchHistory({int limit = 60});

  Future<RateEntry?> current();

  Future<void> setRate({
    required ExchangeRate rate,
    required String userId,
    DateTime? effectiveDate,
    String? note,
  });
}
