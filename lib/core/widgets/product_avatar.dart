import 'dart:typed_data';

import 'package:cajafacil/core/widgets/category_icon.dart';
import 'package:flutter/material.dart';

/// Foto del producto o, si no tiene, el ícono de su categoría.
/// Evita descargar imágenes: ideal para conexiones lentas.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({
    this.photo,
    this.iconKey,
    this.color,
    this.size = 48,
    super.key,
  });

  final Uint8List? photo;
  final String? iconKey;
  final int? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 4);
    final bytes = photo;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: (size * 2).round(),
          errorBuilder: (_, _, _) => _fallback(context, radius),
        ),
      );
    }
    return _fallback(context, radius);
  }

  Widget _fallback(BuildContext context, BorderRadius radius) {
    final base = color != null
        ? Color(color!)
        : Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: radius,
      ),
      child: Icon(CategoryIcons.of(iconKey), color: base, size: size * 0.5),
    );
  }
}
