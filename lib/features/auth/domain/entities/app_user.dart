import 'package:cajafacil/core/auth/permissions.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String name,
    required UserRole role,
    String? email,
    @Default(true) bool active,
  }) = _AppUser;

  const AppUser._();

  bool can(Permission permission) => role.can(permission);

  /// Iniciales para el avatar ("Yamilé Rodríguez" -> "YR").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
