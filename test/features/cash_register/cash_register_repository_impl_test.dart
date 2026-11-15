import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/cash_register/data/cash_register_repository_impl.dart';
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CashRegisterRepositoryImpl repo;
  late String cashierId;
  final clock = FixedClock(DateTime(2026, 11, 15, 8));

  setUp(() async {
    db = createTestDatabase(clock: clock);
    repo = CashRegisterRepositoryImpl(db);
    cashierId = (await AuthRepositoryImpl(
      db,
      hasher: const SecretHasher(iterations: 1),
    ).createUser(name: 'Yoandry', role: UserRole.cashier, pin: '3333')).id;
  });
  tearDown(() => db.close());

  /// Inserta una venta con pagos directamente (el POS aún no existe aquí).
  Future<void> addSale(
    String sessionId, {
    required List<(PaymentMethod, Money)> payments,
    Money? change,
    SaleStatus status = SaleStatus.completed,
  }) async {
    final now = clock.now();
    final saleId = db.ids.newId();
    await db
        .into(db.sales)
        .insert(
          SaleRow(
            id: saleId,
            createdAt: now,
            updatedAt: now,
            deviceId: 'd',
            number: 'A-1',
            sessionId: sessionId,
            cashierId: cashierId,
            rateCupPerUsdX100: 44000,
            subtotalUsdCents: 0,
            discountValue: 0,
            discountUsdCents: 0,
            totalUsdCents: 0,
            totalCupCents: 0,
            totalCostUsdCents: 0,
            changeCurrency: change?.currency,
            changeCents: change?.cents ?? 0,
            status: status,
          ),
        );
    for (final (method, amount) in payments) {
      await db
          .into(db.salePayments)
          .insert(
            SalePaymentRow(
              id: db.ids.newId(),
              createdAt: now,
              updatedAt: now,
              deviceId: 'd',
              saleId: saleId,
              method: method,
              currency: amount.currency,
              amountCents: amount.cents,
            ),
          );
    }
  }

  CurrencyPair pair(int usd, int cup) =>
      CurrencyPair(usd: Money.usd(usd), cup: Money.cup(cup));

  test('abre la caja y no permite abrir otra', () async {
    final s = await repo.open(opening: pair(2000, 500000), userId: cashierId);
    expect(s.isOpen, isTrue);
    expect(s.openedByName, 'Yoandry');
    await expectLater(
      repo.open(opening: pair(0, 0), userId: cashierId),
      throwsA(isA<CashSessionAlreadyOpenException>()),
    );
  });

  test(
    'el resumen incluye ventas, vueltos y movimientos; excluye anuladas',
    () async {
      final s = await repo.open(opening: pair(2000, 500000), userId: cashierId);
      await addSale(
        s.id,
        payments: [(PaymentMethod.cashCup, const Money.cup(200000))],
        change: const Money.cup(35000),
      );
      await addSale(
        s.id,
        payments: [(PaymentMethod.cashUsd, const Money.usd(1000))],
      );
      await addSale(
        s.id,
        payments: [(PaymentMethod.cashCup, const Money.cup(999900))],
        status: SaleStatus.voided,
      );
      await repo.addMovement(
        sessionId: s.id,
        type: CashMovementType.cashOut,
        amount: const Money.cup(120000),
        reason: 'Pago del pan',
        userId: cashierId,
      );

      final summary = await repo.watchSummary(s.id).first;
      expect(summary.salesCount, 2);
      // CUP: 5000 + 2000 − 350 − 1200 = 5450 ; USD: 20 + 10 = 30
      expect(summary.expected, pair(3000, 545000));
    },
  );

  test('cerrar guarda esperado, contado y diferencia', () async {
    final s = await repo.open(opening: pair(0, 100000), userId: cashierId);
    await addSale(
      s.id,
      payments: [(PaymentMethod.cashCup, const Money.cup(50000))],
    );

    final closed = await repo.close(
      sessionId: s.id,
      counted: pair(0, 145000),
      userId: cashierId,
      countDetail: {
        Currency.cup.code: {1000: 1, 200: 2, 50: 1},
      },
      note: ' falta un billete de 50 ',
    );

    expect(closed.isOpen, isFalse);
    expect(closed.expected, pair(0, 150000));
    expect(closed.difference, pair(0, -5000));
    expect(closed.note, 'falta un billete de 50');
    expect(await repo.openSession(), isNull);
    expect(await repo.watchClosedSessions().first, hasLength(1));
  });

  test('no se puede mover efectivo en una caja cerrada', () async {
    final s = await repo.open(opening: pair(0, 0), userId: cashierId);
    await repo.close(sessionId: s.id, counted: pair(0, 0), userId: cashierId);
    await expectLater(
      repo.addMovement(
        sessionId: s.id,
        type: CashMovementType.cashIn,
        amount: const Money.cup(100),
        reason: 'x',
        userId: cashierId,
      ),
      throwsA(isA<CashSessionNotOpenException>()),
    );
  });

  test('watchClosedSessions filtra por usuario', () async {
    final s = await repo.open(opening: pair(0, 0), userId: cashierId);
    await repo.close(sessionId: s.id, counted: pair(0, 0), userId: cashierId);
    expect(await repo.watchClosedSessions(userId: 'otro').first, isEmpty);
    expect(
      await repo.watchClosedSessions(userId: cashierId).first,
      hasLength(1),
    );
  });
}
