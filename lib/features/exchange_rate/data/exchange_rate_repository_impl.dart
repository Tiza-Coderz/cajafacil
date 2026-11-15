import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/features/exchange_rate/domain/entities/rate_entry.dart';
import 'package:cajafacil/features/exchange_rate/domain/repositories/exchange_rate_repository.dart';
import 'package:drift/drift.dart';

class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  ExchangeRateRepositoryImpl(this._db);

  final AppDatabase _db;

  JoinedSelectStatement<HasResultSet, dynamic> _query({int? limit}) {
    final rates = _db.exchangeRates;
    final query =
        _db.select(rates).join([
            leftOuterJoin(_db.users, _db.users.id.equalsExp(rates.createdBy)),
          ])
          ..where(rates.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.desc(rates.effectiveDate),
            OrderingTerm.desc(rates.createdAt),
          ]);
    if (limit != null) query.limit(limit);
    return query;
  }

  RateEntry _map(TypedResult row) {
    final rate = row.readTable(_db.exchangeRates);
    final user = row.readTableOrNull(_db.users);
    return RateEntry(
      id: rate.id,
      rate: ExchangeRate(rate.cupPerUsdX100),
      effectiveDate: rate.effectiveDate,
      createdAt: rate.createdAt,
      createdByName: user?.name ?? '—',
      note: rate.note,
    );
  }

  @override
  Stream<RateEntry?> watchCurrent() => _query(
    limit: 1,
  ).watch().map((rows) => rows.isEmpty ? null : _map(rows.first));

  @override
  Future<RateEntry?> current() async {
    final rows = await _query(limit: 1).get();
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Stream<List<RateEntry>> watchHistory({int limit = 60}) =>
      _query(limit: limit).watch().map((rows) => rows.map(_map).toList());

  @override
  Future<void> setRate({
    required ExchangeRate rate,
    required String userId,
    DateTime? effectiveDate,
    String? note,
  }) async {
    final now = _db.clock.now();
    final trimmedNote = note?.trim();
    final row = ExchangeRateRow(
      id: _db.ids.newId(),
      createdAt: now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      cupPerUsdX100: rate.cupPerUsdX100,
      effectiveDate: effectiveDate ?? now,
      note: (trimmedNote?.isEmpty ?? true) ? null : trimmedNote,
      createdBy: userId,
    );
    await _db.writeSynced(_db.exchangeRates, row, entityId: row.id);
  }
}
