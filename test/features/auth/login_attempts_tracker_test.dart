import 'package:cajafacil/core/utils/clock.dart';
import 'package:cajafacil/features/auth/domain/services/login_attempts_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixedClock clock;
  late LoginAttemptsTracker tracker;

  setUp(() {
    clock = FixedClock(DateTime(2026, 11, 15, 9));
    tracker = LoginAttemptsTracker(maxAttempts: 3, clock: clock);
  });

  test('descuenta intentos y bloquea al llegar al máximo', () {
    expect(tracker.registerFailure('u1'), 2);
    expect(tracker.registerFailure('u1'), 1);
    expect(tracker.registerFailure('u1'), 0);
    expect(tracker.remainingLock('u1'), const Duration(seconds: 30));
  });

  test('el bloqueo expira con el tiempo y reinicia el contador', () {
    for (var i = 0; i < 3; i++) {
      tracker.registerFailure('u1');
    }
    clock.advance(const Duration(seconds: 31));
    expect(tracker.remainingLock('u1'), isNull);
    expect(tracker.registerFailure('u1'), 2);
  });

  test('un acceso correcto limpia los fallos', () {
    tracker
      ..registerFailure('u1')
      ..registerFailure('u1')
      ..reset('u1');
    expect(tracker.registerFailure('u1'), 2);
  });

  test('los usuarios no se afectan entre sí', () {
    for (var i = 0; i < 3; i++) {
      tracker.registerFailure('u1');
    }
    expect(tracker.remainingLock('u2'), isNull);
  });
}
