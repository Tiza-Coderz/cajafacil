import 'package:cajafacil/app/router/app_modules.dart';
import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';

/// Decide a dónde redirigir según la sesión y los permisos.
/// Función pura para poder testearla sin widgets.
String? authRedirect({required AppUser? user, required String location}) {
  final goingToLogin = location == Routes.login;
  if (user == null) return goingToLogin ? null : Routes.login;
  if (goingToLogin) return Routes.home;

  final required = permissionForLocation(location);
  if (required != null && !user.can(required)) return Routes.home;
  return null;
}
