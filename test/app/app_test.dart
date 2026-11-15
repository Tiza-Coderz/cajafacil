import 'package:cajafacil/app/app.dart';
import 'package:cajafacil/core/database/database_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  testWidgets('arranca, siembra la demo y muestra el acceso por usuario', (
    tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CajaFacilApp(),
      ),
    );
    // El hash de PIN del seed corre fuera del reloj falso del test.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Quién va a trabajar?'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('Yoandry Fernández'), findsOneWidget);
    expect(find.text('Modo demostración'), findsOneWidget);

    // Drift cierra sus streams con un timer de 0 ms al desmontar.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
