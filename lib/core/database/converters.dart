import 'package:drift/drift.dart';

/// Guarda `DateTime` como milisegundos UTC desde epoch.
///
/// Drift por defecto usa segundos; para "último cambio gana" en la
/// sincronización se necesita precisión de milisegundos.
class EpochMsConverter extends TypeConverter<DateTime, int> {
  const EpochMsConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true).toLocal();

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}
