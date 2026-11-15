import 'package:uuid/uuid.dart';

/// Reloj inyectable: permite tests deterministas de fechas y sincronización.
class Clock {
  const Clock();

  DateTime now() => DateTime.now();
}

class FixedClock extends Clock {
  FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}

/// Genera UUID v7: únicos entre dispositivos y ordenables por tiempo.
class IdGenerator {
  const IdGenerator();

  static const _uuid = Uuid();

  String newId() => _uuid.v7();
}
