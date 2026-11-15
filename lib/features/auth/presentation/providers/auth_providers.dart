import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';
import 'package:cajafacil/features/auth/domain/repositories/auth_repository.dart';
import 'package:cajafacil/features/auth/domain/services/login_attempts_tracker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepositoryImpl(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
LoginAttemptsTracker loginAttemptsTracker(Ref ref) => LoginAttemptsTracker();

@riverpod
Stream<List<AppUser>> activeUsers(Ref ref) =>
    ref.watch(authRepositoryProvider).watchActiveUsers();

@riverpod
Stream<List<AppUser>> allUsers(Ref ref) =>
    ref.watch(authRepositoryProvider).watchAllUsers();

/// Resultado de un intento de acceso, pensado para mostrar mensajes claros.
sealed class LoginResult {
  const LoginResult();
}

class LoginSuccess extends LoginResult {
  const LoginSuccess(this.user);
  final AppUser user;
}

class LoginInvalid extends LoginResult {
  const LoginInvalid(this.remainingAttempts);
  final int remainingAttempts;
}

class LoginLocked extends LoginResult {
  const LoginLocked(this.remaining);
  final Duration remaining;
}

/// Usuario con sesión abierta (null = nadie en caja).
@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  AppUser? build() => null;

  Future<LoginResult> loginWithPin(AppUser user, String pin) => _attempt(
    user.id,
    () => ref.read(authRepositoryProvider).verifyPin(user.id, pin),
  );

  Future<LoginResult> loginWithPassword(String email, String password) {
    final key = 'email:${email.trim().toLowerCase()}';
    return _attempt(
      key,
      () => ref.read(authRepositoryProvider).verifyPassword(email, password),
    );
  }

  void logout() => state = null;

  Future<LoginResult> _attempt(
    String key,
    Future<AppUser?> Function() verify,
  ) async {
    final tracker = ref.read(loginAttemptsTrackerProvider);
    final locked = tracker.remainingLock(key);
    if (locked != null) return LoginLocked(locked);

    final user = await verify();
    if (user == null) {
      final remaining = tracker.registerFailure(key);
      return remaining == 0
          ? LoginLocked(tracker.lockDuration)
          : LoginInvalid(remaining);
    }
    tracker.reset(key);
    state = user;
    return LoginSuccess(user);
  }
}
