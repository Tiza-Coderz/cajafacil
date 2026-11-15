import 'package:cajafacil/core/sync/remote_sync_api.dart';

/// Servidor de sincronización en memoria con las mismas reglas que
/// `supabase/migrations/0001_sync_records.sql`: "último cambio gana" y
/// `seq` del servidor como cursor.
class FakeSyncApi implements RemoteSyncApi {
  final Map<String, RemoteRecord> _rows = {};
  int _seq = 0;
  int pushCalls = 0;
  bool offline = false;

  List<RemoteRecord> get records => _rows.values.toList();

  @override
  Future<void> push(List<RemoteRecord> records) async {
    if (offline) throw const SyncNetworkException('Sin conexión');
    pushCalls++;
    for (final r in records) {
      final key = '${r.entity}/${r.id}';
      final current = _rows[key];
      if (current != null &&
          !r.winsOver(current.updatedAtMs, current.deviceId)) {
        continue; // El trigger descarta la versión vieja.
      }
      _rows[key] = RemoteRecord(
        entity: r.entity,
        id: r.id,
        payload: Map.of(r.payload),
        updatedAtMs: r.updatedAtMs,
        deviceId: r.deviceId,
        seq: ++_seq,
      );
    }
  }

  @override
  Future<PullPage> pull({
    required int afterSeq,
    required String excludeDeviceId,
    int limit = 500,
  }) async {
    if (offline) throw const SyncNetworkException('Sin conexión');
    final page =
        (_rows.values
                .where((r) => r.seq > afterSeq && r.deviceId != excludeDeviceId)
                .toList()
              ..sort((a, b) => a.seq.compareTo(b.seq)))
            .take(limit)
            .toList();
    return PullPage(page, page.isEmpty ? afterSeq : page.last.seq);
  }
}
