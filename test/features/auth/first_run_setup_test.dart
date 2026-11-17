import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/auth/presentation/widgets/first_run_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  testWidgets('crea el negocio y el dueño en un equipo nuevo', (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(
            AuthRepositoryImpl(db, hasher: const SecretHasher(iterations: 1)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: FirstRunSetup())),
        ),
      ),
    );

    // Sin Supabase configurado solo se ofrece crear el negocio.
    expect(find.text('Vincular con la nube'), findsNothing);
    await tester.tap(find.text('Crear mi negocio'));
    await tester.pumpAndSettle();

    Finder field(String label) => find.widgetWithText(TextField, label);

    // Validación: los PIN deben coincidir.
    await tester.enterText(field('Nombre del negocio'), 'Cafetería El Patio');
    await tester.enterText(
      field('Su nombre y apellido (dueño)'),
      'María González',
    );
    await tester.enterText(field('PIN de 4 dígitos'), '4321');
    await tester.enterText(field('Repita el PIN'), '4322');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pump();
    expect(find.text('Los PIN no coinciden'), findsOneWidget);

    await tester.enterText(field('Repita el PIN'), '4321');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    final users = await tester.runAsync(() => db.select(db.users).get());
    expect(users, hasLength(1));
    expect(users!.single.name, 'María González');
    expect(users.single.role, UserRole.owner);
    final business = await tester.runAsync(
      () => db.select(db.businessSettings).getSingle(),
    );
    expect(business!.name, 'Cafetería El Patio');
    expect(find.textContaining('Toque "María González"'), findsOneWidget);
  });
}
