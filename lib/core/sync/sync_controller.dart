import 'dart:async';

import 'package:cajafacil/core/config/env.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:cajafacil/core/sync/supabase_sync_api.dart';
import 'package:cajafacil/core/sync/sync_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_controller.g.dart';

class SyncStatus {
  const SyncStatus({
    this.linked = false,
    this.syncing = false,
    this.pending = 0,
    this.lastSyncAt,
    this.error,
  });

  final bool linked;
  final bool syncing;
  final int pending;
  final DateTime? lastSyncAt;
  final String? error;

  SyncStatus copyWith({
    bool? linked,
    bool? syncing,
    int? pending,
    DateTime? lastSyncAt,
    String? error,
    bool clearError = false,
  }) => SyncStatus(
    linked: linked ?? this.linked,
    syncing: syncing ?? this.syncing,
    pending: pending ?? this.pending,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Sincronización opcional con Supabase. Solo existe si `SYNC_ENABLED=true`
/// y hay URL y clave configuradas; si no, la app funciona 100 % local.
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  static const _accessKey = 'sync_access_token';
  static const _refreshKey = 'sync_refresh_token';
  static const interval = Duration(minutes: 3);

  Timer? _timer;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  SyncStatus build() {
    ref.onDispose(() => _timer?.cancel());
    if (Env.canSync) unawaited(_restore());
    return const SyncStatus();
  }

  Future<void> _restore() async {
    final linked = await _get(_refreshKey) != null;
    final engine = SyncEngine(_db, _NoopApi());
    state = state.copyWith(
      linked: linked,
      pending: await engine.pendingCount(),
      lastSyncAt: await engine.lastSyncAt(),
    );
    if (linked) _schedule();
  }

  /// Vincula este equipo con la cuenta del dueño en la nube.
  Future<void> link({required String email, required String password}) async {
    final session = await SupabaseSyncApi.signIn(
      baseUrl: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      email: email,
      password: password,
    );
    await _saveSession(session);
    state = state.copyWith(linked: true, clearError: true);
    _schedule();
    await syncNow();
  }

  Future<void> unlink() async {
    _timer?.cancel();
    await (_db.delete(
      _db.syncState,
    )..where((s) => s.key.isIn([_accessKey, _refreshKey]))).go();
    state = state.copyWith(linked: false);
  }

  Future<void> syncNow() async {
    if (!state.linked || state.syncing) return;
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final access = await _get(_accessKey);
      final refresh = await _get(_refreshKey);
      var session = SyncSession(
        accessToken: access ?? '',
        refreshToken: refresh ?? '',
      );
      final api = SupabaseSyncApi(
        baseUrl: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
        session: () => session,
        refresh: () async {
          session = await SupabaseSyncApi.refreshSession(
            baseUrl: Env.supabaseUrl,
            anonKey: Env.supabaseAnonKey,
            refreshToken: session.refreshToken,
          );
          await _saveSession(session);
          return session;
        },
      );
      final engine = SyncEngine(_db, api);
      await engine.sync();
      state = state.copyWith(
        syncing: false,
        pending: await engine.pendingCount(),
        lastSyncAt: await engine.lastSyncAt(),
      );
    } on SyncAuthException catch (e) {
      state = state.copyWith(syncing: false, error: e.message, linked: false);
    } on Object catch (e) {
      // Sin conexión es lo normal en Cuba: se reintenta en el próximo ciclo.
      state = state.copyWith(
        syncing: false,
        error: e is SyncNetworkException
            ? e.message
            : 'No se pudo sincronizar.',
        pending: await SyncEngine(_db, _NoopApi()).pendingCount(),
      );
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => syncNow());
  }

  Future<void> _saveSession(SyncSession s) async {
    for (final (k, v) in [
      (_accessKey, s.accessToken),
      (_refreshKey, s.refreshToken),
    ]) {
      await _db
          .into(_db.syncState)
          .insertOnConflictUpdate(SyncStateCompanion.insert(key: k, value: v));
    }
  }

  Future<String?> _get(String key) async => (await (_db.select(
    _db.syncState,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;
}

/// Para consultar contadores locales sin red.
class _NoopApi implements RemoteSyncApi {
  @override
  Future<PullPage> pull({
    required int afterSeq,
    required String excludeDeviceId,
    int limit = 500,
  }) async => PullPage(const [], afterSeq);

  @override
  Future<void> push(List<RemoteRecord> records) async {}
}
