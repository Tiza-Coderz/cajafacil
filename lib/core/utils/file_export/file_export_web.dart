import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> saveText({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor
    ..click()
    ..remove();
  web.URL.revokeObjectURL(url);
}
