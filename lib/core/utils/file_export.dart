import 'package:cajafacil/core/utils/file_export/file_export_io.dart'
    if (dart.library.js_interop) 'package:cajafacil/core/utils/file_export/file_export_web.dart'
    as impl;

/// Exporta archivos generados por la app.
/// - Web: los descarga con el navegador.
/// - Android: abre el diálogo de compartir (WhatsApp, Drive, correo...).
abstract final class FileExport {
  static Future<void> text({
    required String filename,
    required String content,
    required String mimeType,
  }) => impl.saveText(filename: filename, content: content, mimeType: mimeType);
}
