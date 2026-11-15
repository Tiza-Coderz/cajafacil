import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/features/auth/domain/repositories/auth_repository.dart';
import 'package:cajafacil/features/demo/domain/demo_credentials.dart';
import 'package:drift/drift.dart';

/// Siembra los datos de "Mini-mercado La Esquina, Playa".
///
/// Es idempotente: `seedIfEmpty` solo actúa sobre una BD vacía, y `reset`
/// borra todo y vuelve a sembrar (botón "Restablecer demo").
class DemoSeeder {
  DemoSeeder(this._db, this._auth);

  final AppDatabase _db;
  final AuthRepository _auth;

  Future<bool> seedIfEmpty() async {
    final count = await _db.users.count().getSingle();
    if (count > 0) return false;
    await seed();
    return true;
  }

  Future<void> reset() async {
    await _db.wipeAll();
    await seed();
  }

  Future<void> seed() async {
    await _seedBusiness();
    for (final user in DemoCredentials.users) {
      await _auth.createUser(
        name: user.name,
        role: user.role,
        pin: user.pin,
        email: user.email,
        password: user.password,
      );
    }
  }

  Future<void> _seedBusiness() async {
    final now = _db.clock.now();
    final row = BusinessSettingsRow(
      id: 'business',
      createdAt: now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      name: 'Mini-mercado La Esquina',
      address: 'Calle 42 #1504 e/ 15 y 17, Playa, La Habana',
      nit: '01234567890',
      phone: '+53 7 203 4567',
      whatsapp: '5352345678',
      primaryCurrency: Currency.cup,
      receiptFooter: '¡Gracias por su compra! Vuelva pronto.',
      cupRoundingPesos: 5,
    );
    await _db.writeSynced(_db.businessSettings, row, entityId: row.id);
  }
}
