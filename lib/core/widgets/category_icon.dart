import 'package:flutter/material.dart';

/// Catálogo fijo de íconos de categoría. Se guarda la clave (no el
/// codepoint) para que el tree-shaking de íconos funcione en Web.
abstract final class CategoryIcons {
  static const Map<String, IconData> all = {
    'category': Icons.category_outlined,
    'grains': Icons.rice_bowl_outlined,
    'oil': Icons.water_drop_outlined,
    'meat': Icons.set_meal_outlined,
    'dairy': Icons.egg_outlined,
    'drinks': Icons.local_drink_outlined,
    'beer': Icons.sports_bar_outlined,
    'canned': Icons.inventory_outlined,
    'snacks': Icons.cookie_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'hygiene': Icons.soap_outlined,
    'bakery': Icons.bakery_dining_outlined,
    'produce': Icons.eco_outlined,
  };

  static IconData of(String? key) => all[key] ?? Icons.category_outlined;
}
