import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';

/// Traduce un [LoginResult] fallido a un mensaje para el usuario.
String? loginErrorMessage(LoginResult result) => switch (result) {
  LoginSuccess() => null,
  LoginInvalid(:final remainingAttempts) =>
    remainingAttempts == 1
        ? 'Datos incorrectos. Le queda 1 intento.'
        : 'Datos incorrectos. Le quedan $remainingAttempts intentos.',
  LoginLocked(:final remaining) =>
    'Demasiados intentos. Espere ${remaining.inSeconds.clamp(1, 999)} s.',
};
