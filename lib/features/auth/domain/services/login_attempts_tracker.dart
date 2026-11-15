import 'package:cajafacil/core/utils/clock.dart';

/// Bloquea temporalmente a un usuario tras varios PIN incorrectos seguidos.
///
/// Un PIN de 4 dígitos es fácil de adivinar si no se limita el número de
/// intentos; esto protege la caja de un empleado curioso.
class LoginAttemptsTracker {
  LoginAttemptsTracker({
    this.maxAttempts = 5,
    this.lockDuration = const Duration(seconds: 30),
    Clock clock = const Clock(),
  }) : _clock = clock;

  final int maxAttempts;
  final Duration lockDuration;
  final Clock _clock;

  final _failures = <String, int>{};
  final _lockedUntil = <String, DateTime>{};

  /// Tiempo restante de bloqueo, o `null` si puede intentar.
  Duration? remainingLock(String key) {
    final until = _lockedUntil[key];
    if (until == null) return null;
    final remaining = until.difference(_clock.now());
    if (remaining <= Duration.zero) {
      _lockedUntil.remove(key);
      _failures.remove(key);
      return null;
    }
    return remaining;
  }

  /// Registra un fallo y devuelve los intentos que quedan (0 = bloqueado).
  int registerFailure(String key) {
    final failures = (_failures[key] ?? 0) + 1;
    _failures[key] = failures;
    if (failures >= maxAttempts) {
      _lockedUntil[key] = _clock.now().add(lockDuration);
      return 0;
    }
    return maxAttempts - failures;
  }

  void reset(String key) {
    _failures.remove(key);
    _lockedUntil.remove(key);
  }
}
