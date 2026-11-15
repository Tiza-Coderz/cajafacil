import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/exchange_rate/data/exchange_rate_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ExchangeRateRepositoryImpl repo;
  late String userId;
  final clock = FixedClock(DateTime(2026, 11, 15, 9));

  setUp(() async {
    db = createTestDatabase(clock: clock);
    repo = ExchangeRateRepositoryImpl(db);
    final auth = AuthRepositoryImpl(
      db,
      hasher: const SecretHasher(iterations: 1),
    );
    userId = (await auth.createUser(
      name: 'Yamilé Rodríguez',
      role: UserRole.manager,
      pin: '2222',
    )).id;
  });
  tearDown(() => db.close());

  test('sin tasas, la vigente es null', () async {
    expect(await repo.current(), isNull);
  });

  test('la vigente es la de fecha efectiva más reciente', () async {
    await repo.setRate(
      rate: ExchangeRate.units(440),
      userId: userId,
      effectiveDate: DateTime(2026, 11, 15),
    );
    // Se registra después una tasa retroactiva de ayer: no debe ganar.
    await repo.setRate(
      rate: ExchangeRate.units(430),
      userId: userId,
      effectiveDate: DateTime(2026, 11, 14),
    );

    final current = await repo.current();
    expect(current!.rate, ExchangeRate.units(440));
    expect(current.createdByName, 'Yamilé Rodríguez');
  });

  test('el historial viene ordenado y guarda la nota', () async {
    for (final (day, value) in [(13, 420), (14, 430), (15, 440)]) {
      await repo.setRate(
        rate: ExchangeRate.units(value),
        userId: userId,
        effectiveDate: DateTime(2026, 11, day),
        note: day == 15 ? '  tasa de la mañana ' : '',
      );
    }
    final history = await repo.watchHistory().first;
    expect(history.map((e) => e.rate.cupPerUsdX100), [44000, 43000, 42000]);
    expect(history.first.note, 'tasa de la mañana');
    expect(history.last.note, isNull);
  });

  test('cada tasa queda en el outbox para sincronizar', () async {
    await repo.setRate(rate: ExchangeRate.units(440), userId: userId);
    final outbox = await db.select(db.syncOutbox).get();
    expect(outbox.where((o) => o.entity == 'exchange_rates'), hasLength(1));
  });
}
