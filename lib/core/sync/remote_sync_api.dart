import 'package:meta/meta.dart';

/// Un registro tal como viaja al servidor: la fila completa en JSON más los
/// metadatos para resolver conflictos ("último cambio gana").
@immutable
class RemoteRecord {
  const RemoteRecord({
    required this.entity,
    required this.id,
    required this.payload,
    required this.updatedAtMs,
    required this.deviceId,
    this.seq = 0,
  });

  factory RemoteRecord.fromJson(Map<String, Object?> json) => RemoteRecord(
    entity: json['entity']! as String,
    id: json['id']! as String,
    payload: (json['payload']! as Map).cast<String, Object?>(),
    updatedAtMs: (json['updated_at']! as num).toInt(),
    deviceId: json['device_id']! as String,
    seq: (json['seq'] as num?)?.toInt() ?? 0,
  );

  final String entity;
  final String id;
  final Map<String, Object?> payload;
  final int updatedAtMs;
  final String deviceId;

  /// Orden asignado por el servidor; es el cursor de descarga. No se usa la
  /// fecha del cliente como cursor porque un equipo que estuvo días sin
  /// conexión subiría cambios "viejos" que otro equipo nunca bajaría.
  final int seq;

  Map<String, Object?> toJson() => {
    'entity': entity,
    'id': id,
    'payload': payload,
    'updated_at': updatedAtMs,
    'device_id': deviceId,
  };

  /// ¿Gana este registro frente a otra versión (fecha y dispositivo)?
  bool winsOver(int otherUpdatedAtMs, String otherDevice) =>
      updatedAtMs > otherUpdatedAtMs ||
      (updatedAtMs == otherUpdatedAtMs && deviceId.compareTo(otherDevice) > 0);
}

@immutable
class PullPage {
  const PullPage(this.records, this.lastSeq);

  final List<RemoteRecord> records;
  final int lastSeq;
}

class SyncAuthException implements Exception {
  const SyncAuthException([this.message = 'Sesión de sincronización vencida.']);

  final String message;

  @override
  String toString() => message;
}

class SyncNetworkException implements Exception {
  const SyncNetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Servidor de sincronización. La implementación real es Supabase; en los
/// tests se usa un servidor en memoria con las mismas reglas.
abstract interface class RemoteSyncApi {
  /// Sube registros (upsert). El servidor aplica "último cambio gana".
  Future<void> push(List<RemoteRecord> records);

  /// Baja registros con `seq` mayor que [afterSeq], excluyendo los del
  /// propio equipo para ahorrar datos.
  Future<PullPage> pull({
    required int afterSeq,
    required String excludeDeviceId,
    int limit = 500,
  });
}
