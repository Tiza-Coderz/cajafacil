import 'dart:async';
import 'dart:convert';

import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/cash_register/domain/entities/cash_session.dart';
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:drift/drift.dart';

class CashRegisterRepositoryImpl implements CashRegisterRepository {
  CashRegisterRepositoryImpl(this._db);

  final AppDatabase _db;

  // Alias únicos: la misma instancia se usa al consultar y al leer filas.
  late final $UsersTable _openedBy = _db.alias(_db.users, 'opened_by_user');
  late final $UsersTable _closedBy = _db.alias(_db.users, 'closed_by_user');

  JoinedSelectStatement<HasResultSet, dynamic> _query() {
    final s = _db.cashSessions;
    final opened = _openedBy;
    final closed = _closedBy;
    return _db.select(s).join([
      innerJoin(opened, opened.id.equalsExp(s.openedBy)),
      leftOuterJoin(closed, closed.id.equalsExp(s.closedBy)),
    ])..where(s.deletedAt.isNull());
  }

  CashSession _map(TypedResult row) {
    final s = row.readTable(_db.cashSessions);
    final opened = row.readTable(_openedBy);
    final closed = row.readTableOrNull(_closedBy);
    CurrencyPair? pair(int? usd, int? cup) => usd == null || cup == null
        ? null
        : CurrencyPair(usd: Money.usd(usd), cup: Money.cup(cup));
    return CashSession(
      id: s.id,
      openedById: s.openedBy,
      openedByName: opened.name,
      openedAt: s.openedAt,
      opening: CurrencyPair(
        usd: Money.usd(s.openingUsdCents),
        cup: Money.cup(s.openingCupCents),
      ),
      status: s.status,
      closedByName: closed?.name,
      closedAt: s.closedAt,
      expected: pair(s.expectedUsdCents, s.expectedCupCents),
      counted: pair(s.countedUsdCents, s.countedCupCents),
      difference: pair(s.diffUsdCents, s.diffCupCents),
      note: s.note,
    );
  }

  @override
  Stream<CashSession?> watchOpenSession() {
    final query = _query()
      ..where(_db.cashSessions.status.equalsValue(CashSessionStatus.open))
      ..limit(1);
    return query.watchSingleOrNull().map((r) => r == null ? null : _map(r));
  }

  @override
  Future<CashSession?> openSession() async {
    final query = _query()
      ..where(_db.cashSessions.status.equalsValue(CashSessionStatus.open))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<CashSession> open({
    required CurrencyPair opening,
    required String userId,
  }) {
    return _db.transaction(() async {
      final current = await openSession();
      if (current != null) {
        throw CashSessionAlreadyOpenException(current.openedByName);
      }
      final now = _db.clock.now();
      final row = CashSessionRow(
        id: _db.ids.newId(),
        createdAt: now,
        updatedAt: now,
        deviceId: await _db.deviceId(),
        openedBy: userId,
        openedAt: now,
        openingUsdCents: opening.usd.cents,
        openingCupCents: opening.cup.cents,
        status: CashSessionStatus.open,
      );
      await _db.writeSynced(_db.cashSessions, row, entityId: row.id);
      return (await openSession())!;
    });
  }

  @override
  Future<void> addMovement({
    required String sessionId,
    required CashMovementType type,
    required Money amount,
    required String reason,
    required String userId,
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError.value(amount, 'amount', 'debe ser mayor que 0');
    }
    await _ensureOpen(sessionId);
    final now = _db.clock.now();
    final row = CashMovementRow(
      id: _db.ids.newId(),
      createdAt: now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      sessionId: sessionId,
      type: type,
      currency: amount.currency,
      amountCents: amount.cents,
      reason: reason.trim(),
      userId: userId,
    );
    await _db.writeSynced(_db.cashMovements, row, entityId: row.id);
  }

  Future<CashSessionRow> _ensureOpen(String sessionId) async {
    final row = await (_db.select(
      _db.cashSessions,
    )..where((s) => s.id.equals(sessionId))).getSingle();
    if (row.status != CashSessionStatus.open) {
      throw const CashSessionNotOpenException();
    }
    return row;
  }

  Future<CashSummary> _summary(String sessionId) async {
    final session = await (_db.select(
      _db.cashSessions,
    )..where((s) => s.id.equals(sessionId))).getSingle();

    final sales =
        await (_db.select(_db.sales)..where(
              (s) =>
                  s.sessionId.equals(sessionId) &
                  s.status.equalsValue(SaleStatus.completed) &
                  s.deletedAt.isNull(),
            ))
            .get();
    final saleIds = sales.map((s) => s.id).toList();
    final payments = saleIds.isEmpty
        ? <SalePaymentRow>[]
        : await (_db.select(
            _db.salePayments,
          )..where((p) => p.saleId.isIn(saleIds) & p.deletedAt.isNull())).get();
    final movements =
        await (_db.select(_db.cashMovements)..where(
              (m) => m.sessionId.equals(sessionId) & m.deletedAt.isNull(),
            ))
            .get();

    return CashReconciliation.summarize(
      opening: CurrencyPair(
        usd: Money.usd(session.openingUsdCents),
        cup: Money.cup(session.openingCupCents),
      ),
      payments: payments.map(
        (p) => PaymentLine(p.method, Money(p.amountCents, p.currency)),
      ),
      changes: sales
          .where((s) => s.changeCurrency != null && s.changeCents > 0)
          .map((s) => Money(s.changeCents, s.changeCurrency!)),
      movements: movements.map(
        (m) => CashMovementLine(m.type, Money(m.amountCents, m.currency)),
      ),
      salesCount: sales.length,
    );
  }

  @override
  Stream<CashSummary> watchSummary(String sessionId) {
    // Se recalcula cuando cambia cualquiera de las tablas involucradas.
    final trigger = _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.sales,
        _db.salePayments,
        _db.cashMovements,
        _db.cashSessions,
      ]),
    );
    late StreamController<CashSummary> controller;
    StreamSubscription<void>? sub;
    Future<void> emit() async {
      if (!controller.isClosed) controller.add(await _summary(sessionId));
    }

    controller = StreamController<CashSummary>(
      onListen: () {
        emit();
        sub = trigger.listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<CashSession> close({
    required String sessionId,
    required CurrencyPair counted,
    required String userId,
    Map<String, Map<int, int>>? countDetail,
    String? note,
  }) {
    return _db.transaction(() async {
      final row = await _ensureOpen(sessionId);
      final summary = await _summary(sessionId);
      final expected = summary.expected;
      final diff = CashReconciliation.difference(
        counted: counted,
        expected: expected,
      );
      final now = _db.clock.now();
      final trimmed = note?.trim();
      final updated = row.copyWith(
        updatedAt: now,
        status: CashSessionStatus.closed,
        closedBy: Value(userId),
        closedAt: Value(now),
        expectedUsdCents: Value(expected.usd.cents),
        expectedCupCents: Value(expected.cup.cents),
        countedUsdCents: Value(counted.usd.cents),
        countedCupCents: Value(counted.cup.cents),
        diffUsdCents: Value(diff.usd.cents),
        diffCupCents: Value(diff.cup.cents),
        countDetailJson: Value(
          countDetail == null
              ? null
              : jsonEncode(
                  countDetail.map(
                    (currency, counts) => MapEntry(
                      currency,
                      counts.map((k, v) => MapEntry('$k', v)),
                    ),
                  ),
                ),
        ),
        note: Value((trimmed?.isEmpty ?? true) ? null : trimmed),
      );
      await _db.writeSynced(_db.cashSessions, updated, entityId: sessionId);
      final result =
          await (_query()..where(_db.cashSessions.id.equals(sessionId)))
              .getSingle();
      return _map(result);
    });
  }

  @override
  Stream<List<CashSession>> watchClosedSessions({
    String? userId,
    int limit = 50,
  }) {
    final s = _db.cashSessions;
    final query = _query()
      ..where(s.status.equalsValue(CashSessionStatus.closed))
      ..orderBy([OrderingTerm.desc(s.closedAt)])
      ..limit(limit);
    if (userId != null) query.where(s.openedBy.equals(userId));
    return query.watch().map((rows) => rows.map(_map).toList());
  }
}
