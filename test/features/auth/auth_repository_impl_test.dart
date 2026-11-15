import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late AuthRepositoryImpl repo;

  setUp(() {
    db = createTestDatabase();
    repo = AuthRepositoryImpl(db, hasher: const SecretHasher(iterations: 2));
  });
  tearDown(() => db.close());

  test('crea usuario sin guardar el PIN en claro', () async {
    final user = await repo.createUser(
      name: 'Yoandry Fernández',
      role: UserRole.cashier,
      pin: '3333',
    );
    final row = await db.select(db.users).getSingle();
    expect(user.name, 'Yoandry Fernández');
    expect(row.pinHash, isNot(contains('3333')));
    expect(row.pinSalt, isNotEmpty);
  });

  test('verifyPin acepta el correcto y rechaza el incorrecto', () async {
    final user = await repo.createUser(
      name: 'Yamilé',
      role: UserRole.manager,
      pin: '2222',
    );
    expect(await repo.verifyPin(user.id, '2222'), isNotNull);
    expect(await repo.verifyPin(user.id, '0000'), isNull);
  });

  test('verifyPassword ignora mayúsculas en el correo', () async {
    await repo.createUser(
      name: 'Carlos',
      role: UserRole.owner,
      pin: '1234',
      email: 'admin@demo.cu',
      password: 'demo1234',
    );
    expect(await repo.verifyPassword('ADMIN@demo.cu', 'demo1234'), isNotNull);
    expect(await repo.verifyPassword('admin@demo.cu', 'otra'), isNull);
  });

  test('el PIN no sirve como contraseña', () async {
    await repo.createUser(
      name: 'Carlos',
      role: UserRole.owner,
      pin: '1234',
      email: 'admin@demo.cu',
      password: 'demo1234',
    );
    expect(await repo.verifyPassword('admin@demo.cu', '1234'), isNull);
  });

  test('changePin reemplaza el PIN anterior', () async {
    final user = await repo.createUser(
      name: 'Yamilé',
      role: UserRole.manager,
      pin: '2222',
    );
    await repo.changePin(user.id, '9876');
    expect(await repo.verifyPin(user.id, '2222'), isNull);
    expect(await repo.verifyPin(user.id, '9876'), isNotNull);
  });

  test('watchActiveUsers ordena por jerarquía', () async {
    await repo.createUser(name: 'Ana', role: UserRole.cashier, pin: '1111');
    await repo.createUser(name: 'Zoe', role: UserRole.owner, pin: '1111');
    final users = await repo.watchActiveUsers().first;
    expect(users.map((u) => u.role), [UserRole.owner, UserRole.cashier]);
  });
}
