import 'package:cajafacil/core/domain/enums.dart';

/// Usuarios de la demo. Se muestran en la pantalla de acceso cuando
/// `DEMO_MODE=true`; en un despliegue real esto no existe.
class DemoUser {
  const DemoUser({
    required this.name,
    required this.role,
    required this.pin,
    this.email,
    this.password,
  });

  final String name;
  final UserRole role;
  final String pin;
  final String? email;
  final String? password;
}

abstract final class DemoCredentials {
  static const ownerEmail = 'admin@demo.cu';
  static const ownerPassword = 'demo1234';

  static const users = [
    DemoUser(
      name: 'Carlos Pérez',
      role: UserRole.owner,
      pin: '1234',
      email: ownerEmail,
      password: ownerPassword,
    ),
    DemoUser(name: 'Yamilé Rodríguez', role: UserRole.manager, pin: '2222'),
    DemoUser(name: 'Yoandry Fernández', role: UserRole.cashier, pin: '3333'),
  ];
}
