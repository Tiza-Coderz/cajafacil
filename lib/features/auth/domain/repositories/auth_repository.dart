import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';

/// No se puede desactivar al último dueño activo (nadie podría administrar).
class LastOwnerException implements Exception {
  const LastOwnerException();

  @override
  String toString() => 'Debe quedar al menos un dueño activo.';
}

abstract interface class AuthRepository {
  Stream<List<AppUser>> watchActiveUsers();

  /// Todos los usuarios (activos e inactivos), para administrarlos.
  Stream<List<AppUser>> watchAllUsers();

  Future<void> setActive(String userId, {required bool active});

  /// Devuelve el usuario si el PIN es correcto; `null` en caso contrario.
  Future<AppUser?> verifyPin(String userId, String pin);

  /// Acceso con correo y contraseña (solo usuarios que la tengan).
  Future<AppUser?> verifyPassword(String email, String password);

  Future<AppUser> createUser({
    required String name,
    required UserRole role,
    required String pin,
    String? email,
    String? password,
  });

  Future<void> changePin(String userId, String newPin);
}
