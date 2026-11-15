import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<List<AppUser>> watchActiveUsers();

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
