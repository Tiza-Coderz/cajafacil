import 'package:intl/intl.dart';

/// Formatos de fecha en español usados en toda la app.
abstract final class AppDates {
  static final _day = DateFormat('d MMM yyyy', 'es');
  static final _time = DateFormat('h:mm a', 'es');
  static final _dayShort = DateFormat('d MMM', 'es');

  static String day(DateTime date) => _day.format(date);

  static String dayShort(DateTime date) => _dayShort.format(date);

  static String time(DateTime date) => _time.format(date);

  /// "hoy, 9:30 a. m." / "ayer, 6:10 p. m." / "12 nov 2026, 8:00 a. m."
  static String relativeDayTime(DateTime date, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(date);
    final diff = today.difference(target).inDays;
    final dayLabel = switch (diff) {
      0 => 'hoy',
      1 => 'ayer',
      _ => day(date),
    };
    return '$dayLabel, ${time(date)}';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
