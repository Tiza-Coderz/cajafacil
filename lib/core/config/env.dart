/// Configuración leída en tiempo de compilación con
/// `flutter run --dart-define-from-file=.env`.
///
/// Ningún secreto vive en el repositorio: ver `.env.example`.
abstract final class Env {
  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  static const syncEnabled = bool.fromEnvironment('SYNC_ENABLED');

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const supportWhatsapp = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
    defaultValue: '5350000000',
  );

  /// La sincronización solo se activa si está habilitada y configurada.
  static bool get canSync =>
      syncEnabled && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
