import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';
import 'package:cajafacil/features/auth/domain/repositories/auth_repository.dart';
import 'package:cajafacil/features/demo/domain/demo_credentials.dart';
import 'package:cajafacil/features/exchange_rate/domain/repositories/exchange_rate_repository.dart';
import 'package:drift/drift.dart';

/// Siembra los datos de "Mini-mercado La Esquina, Playa".
///
/// Es idempotente: `seedIfEmpty` solo actúa sobre una BD vacía, y `reset`
/// borra todo y vuelve a sembrar (botón "Restablecer demo").
class DemoSeeder {
  DemoSeeder(this._db, this._auth, this._rates);

  final AppDatabase _db;
  final AuthRepository _auth;
  final ExchangeRateRepository _rates;

  /// Tasa informal USD→CUP de los últimos 15 días (de más antigua a hoy).
  static const rateHistory = [
    415,
    415,
    418,
    420,
    420,
    422,
    425,
    425,
    428,
    430,
    432,
    435,
    435,
    438,
    440,
  ];

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

  /// Una sola transacción: en Web evita decenas de escrituras a
  /// IndexedDB y deja la BD consistente si algo falla a mitad.
  Future<void> seed() => _db.transaction(() async {
    await _seedBusiness();
    final users = <UserRole, AppUser>{};
    for (final user in DemoCredentials.users) {
      users[user.role] = await _auth.createUser(
        name: user.name,
        role: user.role,
        pin: user.pin,
        email: user.email,
        password: user.password,
      );
    }
    await _seedRates(users[UserRole.manager]!);
  });

  Future<void> _seedRates(AppUser manager) async {
    final now = _db.clock.now();
    final today = DateTime(now.year, now.month, now.day, 8, 30);
    for (var i = 0; i < rateHistory.length; i++) {
      final daysAgo = rateHistory.length - 1 - i;
      await _rates.setRate(
        rate: ExchangeRate.units(rateHistory[i]),
        userId: manager.id,
        effectiveDate: today.subtract(Duration(days: daysAgo)),
        note: daysAgo == 0 ? 'Tasa informal de la mañana' : null,
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
