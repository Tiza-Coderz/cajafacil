import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/exchange_rate/data/exchange_rate_repository_impl.dart';
import 'package:cajafacil/features/exchange_rate/domain/entities/rate_entry.dart';
import 'package:cajafacil/features/exchange_rate/domain/repositories/exchange_rate_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exchange_rate_providers.g.dart';

@Riverpod(keepAlive: true)
ExchangeRateRepository exchangeRateRepository(Ref ref) =>
    ExchangeRateRepositoryImpl(ref.watch(appDatabaseProvider));

/// Tasa vigente, observada por POS, productos y reportes.
@Riverpod(keepAlive: true)
Stream<RateEntry?> currentRate(Ref ref) =>
    ref.watch(exchangeRateRepositoryProvider).watchCurrent();

@riverpod
Stream<List<RateEntry>> rateHistory(Ref ref) =>
    ref.watch(exchangeRateRepositoryProvider).watchHistory();
