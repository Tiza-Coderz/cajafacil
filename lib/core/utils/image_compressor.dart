import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Reduce fotos de productos a miniaturas livianas (pensado para
/// conexiones lentas y para guardarlas en la BD).
abstract final class ImageCompressor {
  static const maxSide = 256;
  static const quality = 70;

  /// Devuelve un JPEG de máximo [maxSide] px por lado, o `null` si los
  /// bytes no son una imagen válida.
  static Uint8List? thumbnail(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized = decoded.width >= decoded.height
        ? (decoded.width > maxSide
              ? img.copyResize(decoded, width: maxSide)
              : decoded)
        : (decoded.height > maxSide
              ? img.copyResize(decoded, height: maxSide)
              : decoded);
    return img.encodeJpg(resized, quality: quality);
  }
}
