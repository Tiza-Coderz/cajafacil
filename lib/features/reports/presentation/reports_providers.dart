import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/reports/data/reports_repository.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reports_providers.g.dart';

@Riverpod(keepAlive: true)
ReportsRepository reportsRepository(Ref ref) =>
    ReportsRepository(ref.watch(appDatabaseProvider));

/// Rango seleccionado (por defecto, últimos 14 días).
@riverpod
class SelectedRange extends _$SelectedRange {
  @override
  ReportRange build() => ReportRange.lastDays(DateTime.now(), 14);

  ReportRange get range => state;

  set range(ReportRange value) => state = value;
}

@riverpod
Future<SalesReport> salesReport(Ref ref) {
  final range = ref.watch(selectedRangeProvider);
  return ref.watch(reportsRepositoryProvider).build(range);
}
