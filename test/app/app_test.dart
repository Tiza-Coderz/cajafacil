import 'package:cajafacil/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la app arranca y muestra la pantalla inicial', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CajaFacilApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('CajaFácil'), findsOneWidget);
  });
}
