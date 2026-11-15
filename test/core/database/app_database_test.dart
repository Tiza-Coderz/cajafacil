import 'dart:convert';

import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final clock = FixedClock(DateTime.utc(2026, 11, 15, 10));

  setUp(() => db = createTestDatabase(clock: clock));
  tearDown(() => db.close());

  UserRow buildUser({String id = 'u1', String name = 'Yamilé'}) {
    final now = clock.now();
    return UserRow(
      id: id,
      createdAt: now,
      updatedAt: now,
      deviceId: 'dev-1',
      name: name,
      role: UserRole.manager,
      pinHash: 'hash',
      pinSalt: 'salt',
      active: true,
    );
  }

  test('deviceId se genera una vez y es estable', () async {
    final first = await db.deviceId();
    final second = await db.deviceId();
    expect(first, isNotEmpty);
    expect(second, first);
  });

  test('writeSynced guarda la fila y la encola en el outbox', () async {
    await db.writeSynced(db.users, buildUser(), entityId: 'u1');

    final users = await db.select(db.users).get();
    final outbox = await db.select(db.syncOutbox).get();

    expect(users.single.name, 'Yamilé');
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'users');
    expect(outbox.single.op, SyncOp.upsert);
    expect(outbox.single.status, OutboxStatus.pending);
    final payload =
        jsonDecode(outbox.single.payloadJson) as Map<String, Object?>;
    expect(payload['name'], 'Yamilé');
  });

  test('writeSynced actualiza si el id ya existe', () async {
    await db.writeSynced(db.users, buildUser(), entityId: 'u1');
    await db.writeSynced(
      db.users,
      buildUser(name: 'Yamilé Pérez'),
      entityId: 'u1',
    );

    final users = await db.select(db.users).get();
    expect(users.single.name, 'Yamilé Pérez');
    expect(await db.select(db.syncOutbox).get(), hasLength(2));
  });

  test('las claves foráneas están activas', () async {
    final now = clock.now();
    final orphanRate = ExchangeRateRow(
      id: 'r1',
      createdAt: now,
      updatedAt: now,
      deviceId: 'dev-1',
      cupPerUsdX100: 39000,
      effectiveDate: now,
      createdBy: 'no-existe',
    );
    await expectLater(
      db.into(db.exchangeRates).insert(orphanRate),
      throwsA(anything),
    );
  });

  test('wipeAll borra los datos pero conserva el deviceId', () async {
    final deviceId = await db.deviceId();
    await db.writeSynced(db.users, buildUser(), entityId: 'u1');

    await db.wipeAll();

    expect(await db.select(db.users).get(), isEmpty);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
    expect(await db.deviceId(), deviceId);
  });
}
