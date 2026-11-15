import 'package:cajafacil/app/router/route_guards.dart';
import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cashier = AppUser(id: 'c', name: 'Yoandry', role: UserRole.cashier);
  const owner = AppUser(id: 'o', name: 'Carlos', role: UserRole.owner);

  test('sin sesión todo redirige al login', () {
    expect(authRedirect(user: null, location: Routes.pos), Routes.login);
    expect(authRedirect(user: null, location: Routes.login), isNull);
  });

  test('con sesión el login redirige al inicio', () {
    expect(authRedirect(user: cashier, location: Routes.login), Routes.home);
  });

  test('el cajero no puede entrar a reportes ni ajustes', () {
    expect(authRedirect(user: cashier, location: Routes.reports), Routes.home);
    expect(
      authRedirect(user: cashier, location: '${Routes.settings}/negocio'),
      Routes.home,
    );
    expect(authRedirect(user: cashier, location: Routes.pos), isNull);
  });

  test('el dueño entra a todo', () {
    for (final route in [Routes.reports, Routes.settings, Routes.products]) {
      expect(authRedirect(user: owner, location: route), isNull);
    }
  });
}
