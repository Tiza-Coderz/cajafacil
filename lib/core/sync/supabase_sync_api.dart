import 'dart:convert';

import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Tokens de sesión de Supabase Auth (GoTrue).
@immutable
class SyncSession {
  const SyncSession({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Implementación sobre la API REST de Supabase (PostgREST + GoTrue), sin
/// SDK: menos dependencias y control total de lo que viaja por la red.
///
/// El esquema del servidor está en `supabase/migrations/`.
class SupabaseSyncApi implements RemoteSyncApi {
  SupabaseSyncApi({
    required this.baseUrl,
    required this.anonKey,
    required SyncSession Function() session,
    required Future<SyncSession> Function() refresh,
    http.Client? client,
  }) : _session = session,
       _refresh = refresh,
       _client = client ?? http.Client();

  final String baseUrl;
  final String anonKey;
  final SyncSession Function() _session;
  final Future<SyncSession> Function() _refresh;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  /// Inicia sesión con correo y contraseña del dueño (vincular equipo).
  static Future<SyncSession> signIn({
    required String baseUrl,
    required String anonKey,
    required String email,
    required String password,
    http.Client? client,
  }) => _token(
    baseUrl: baseUrl,
    anonKey: anonKey,
    grantType: 'password',
    body: {'email': email.trim(), 'password': password},
    client: client,
  );

  static Future<SyncSession> refreshSession({
    required String baseUrl,
    required String anonKey,
    required String refreshToken,
    http.Client? client,
  }) => _token(
    baseUrl: baseUrl,
    anonKey: anonKey,
    grantType: 'refresh_token',
    body: {'refresh_token': refreshToken},
    client: client,
  );

  static Future<SyncSession> _token({
    required String baseUrl,
    required String anonKey,
    required String grantType,
    required Map<String, String> body,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final res = await c
        .post(
          Uri.parse('$baseUrl/auth/v1/token?grant_type=$grantType'),
          headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (res.statusCode == 400 || res.statusCode == 401) {
      throw const SyncAuthException('Correo o contraseña incorrectos.');
    }
    if (res.statusCode >= 300) {
      throw SyncNetworkException('Error ${res.statusCode} al iniciar sesión.');
    }
    final json = jsonDecode(res.body) as Map<String, Object?>;
    return SyncSession(
      accessToken: json['access_token']! as String,
      refreshToken: json['refresh_token']! as String,
    );
  }

  Map<String, String> _headers(String token) => {
    'apikey': anonKey,
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  /// Repite una vez con token renovado si el servidor responde 401.
  Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
  ) async {
    try {
      var res = await request(_session().accessToken).timeout(_timeout);
      if (res.statusCode == 401) {
        final fresh = await _refresh();
        res = await request(fresh.accessToken).timeout(_timeout);
      }
      if (res.statusCode == 401) throw const SyncAuthException();
      if (res.statusCode >= 300) {
        throw SyncNetworkException('Error ${res.statusCode}: ${res.body}');
      }
      return res;
    } on SyncAuthException {
      rethrow;
    } on SyncNetworkException {
      rethrow;
    } on Exception catch (e) {
      throw SyncNetworkException('Sin conexión con el servidor ($e).');
    }
  }

  @override
  Future<void> push(List<RemoteRecord> records) async {
    if (records.isEmpty) return;
    await _send(
      (token) => _client.post(
        Uri.parse(
          '$baseUrl/rest/v1/sync_records?on_conflict=business_id,entity,id',
        ),
        headers: {
          ..._headers(token),
          'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        body: jsonEncode([for (final r in records) r.toJson()]),
      ),
    );
  }

  @override
  Future<PullPage> pull({
    required int afterSeq,
    required String excludeDeviceId,
    int limit = 500,
  }) async {
    final uri = Uri.parse('$baseUrl/rest/v1/sync_records').replace(
      queryParameters: {
        'select': 'entity,id,payload,updated_at,device_id,seq',
        'seq': 'gt.$afterSeq',
        'device_id': 'neq.$excludeDeviceId',
        'order': 'seq.asc',
        'limit': '$limit',
      },
    );
    final res = await _send(
      (token) => _client.get(uri, headers: _headers(token)),
    );
    final rows = (jsonDecode(res.body) as List).cast<Map<String, Object?>>();
    final records = rows.map(RemoteRecord.fromJson).toList();
    return PullPage(records, records.isEmpty ? afterSeq : records.last.seq);
  }
}
