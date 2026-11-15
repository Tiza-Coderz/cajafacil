import 'dart:typed_data';

import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/settings/data/settings_repository.dart';
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('sin datos devuelve un perfil por defecto', () async {
    expect(await repo.watchProfile().first, BusinessProfile.fallback);
  });

  test('guarda y lee el perfil con redondeo y moneda', () async {
    await repo.saveProfile(
      const BusinessProfile(
        name: '  Cafetería El Malecón ',
        address: 'Malecón #102, Centro Habana',
        nit: '01234567890',
        primaryCurrency: Currency.usd,
        cupRounding: CupRounding.ten,
      ),
    );
    final p = await repo.watchProfile().first;
    expect(p.name, 'Cafetería El Malecón');
    expect(p.primaryCurrency, Currency.usd);
    expect(p.cupRounding, CupRounding.ten);
  });

  test('el logo se guarda aparte y se puede quitar', () async {
    final logo = Uint8List.fromList([1, 2, 3, 4]);
    await repo.saveProfile(BusinessProfile(name: 'X', logo: logo));
    expect(await repo.watchLogo().first, logo);

    await repo.saveProfile(const BusinessProfile(name: 'X'));
    expect(await repo.watchLogo().first, isNull);
  });
}
