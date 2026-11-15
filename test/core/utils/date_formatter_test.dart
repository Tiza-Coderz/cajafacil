import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  final now = DateTime(2026, 11, 15, 18);

  test('muestra "hoy" y "ayer"', () {
    expect(
      AppDates.relativeDayTime(DateTime(2026, 11, 15, 9, 30), now: now),
      startsWith('hoy, 9:30'),
    );
    expect(
      AppDates.relativeDayTime(DateTime(2026, 11, 14, 9, 30), now: now),
      startsWith('ayer, 9:30'),
    );
  });

  test('fechas anteriores muestran día y mes en español', () {
    expect(
      AppDates.relativeDayTime(DateTime(2026, 11, 2, 8), now: now),
      startsWith('2 nov 2026'),
    );
  });
}
