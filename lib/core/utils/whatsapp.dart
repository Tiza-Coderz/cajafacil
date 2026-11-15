import 'package:url_launcher/url_launcher.dart';

/// Enlaces wa.me: abren WhatsApp (app o web) con el texto ya escrito.
abstract final class WhatsApp {
  /// [phone] en formato internacional sin "+" (ej. 5352345678). Si es
  /// null, WhatsApp deja elegir el contacto.
  static Uri link({String? phone, String? text}) {
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    return Uri.https(
      'wa.me',
      digits.isEmpty ? '/' : '/$digits',
      text == null ? null : {'text': text},
    );
  }

  static Future<bool> open({String? phone, String? text}) => launchUrl(
    link(phone: phone, text: text),
    mode: LaunchMode.externalApplication,
  );
}
