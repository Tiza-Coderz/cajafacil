import 'package:flutter/material.dart';

/// Paleta de marca. El azul #0f4c75 es el color principal del producto.
abstract final class AppColors {
  static const primary = Color(0xFF0F4C75);
  static const primaryLight = Color(0xFF3282B8);
  static const accent = Color(0xFFF2A541);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFED6C02);
  static const danger = Color(0xFFC62828);
  static const whatsapp = Color(0xFF25D366);

  /// Colores por moneda para distinguirlas de un vistazo en el POS.
  static const usd = Color(0xFF1B5E20);
  static const cup = Color(0xFF0F4C75);
}
