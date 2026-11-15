import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/auth/permissions.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/file_export.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:cajafacil/features/reports/domain/report_csv.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:cajafacil/features/reports/presentation/report_pdf.dart';
import 'package:cajafacil/features/reports/presentation/reports_providers.dart';
import 'package:cajafacil/features/reports/presentation/widgets/report_charts.dart';
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:cajafacil/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

enum _Export { pdf, csvProducts, csvDaily }

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    SalesReport report,
    _Export kind,
  ) async {
    final costs =
        ref.read(sessionProvider)?.can(Permission.viewCostsAndProfit) ?? false;
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    switch (kind) {
      case _Export.pdf:
        final business =
            ref.read(businessProfileProvider).value ?? BusinessProfile.fallback;
        final bytes = await ReportPdf.build(
          report,
          businessName: business.name,
          includeCosts: costs,
        );
        await Printing.sharePdf(bytes: bytes, filename: 'reporte-$stamp.pdf');
      case _Export.csvProducts:
        await FileExport.text(
          filename: 'ventas-por-producto-$stamp.csv',
          content: ReportCsv.byProduct(report, includeCosts: costs),
          mimeType: 'text/csv',
        );
      case _Export.csvDaily:
        await FileExport.text(
          filename: 'ventas-por-dia-$stamp.csv',
          content: ReportCsv.daily(report, includeCosts: costs),
          mimeType: 'text/csv',
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(salesReportProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes'),
          actions: [
            if (report.value case final r?)
              PopupMenuButton<_Export>(
                tooltip: 'Exportar',
                icon: const Icon(Icons.ios_share),
                onSelected: (k) => _export(context, ref, r, k),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _Export.pdf,
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Informe PDF'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _Export.csvProducts,
                    child: ListTile(
                      leading: Icon(Icons.table_chart_outlined),
                      title: Text('Excel/CSV por producto'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _Export.csvDaily,
                    child: ListTile(
                      leading: Icon(Icons.calendar_month_outlined),
                      title: Text('Excel/CSV por día'),
                    ),
                  ),
                ],
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.accent,
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Productos'),
              Tab(text: 'Equipo'),
              Tab(text: 'Stock'),
            ],
          ),
        ),
        body: Column(
          children: [
            const _RangeSelector(),
            Expanded(
              child: report.when(
                loading: () => const LoadingView(message: 'Calculando…'),
                error: (_, _) => ErrorView(
                  message: 'No se pudo generar el reporte.',
                  onRetry: () => ref.invalidate(salesReportProvider),
                ),
                data: (r) => TabBarView(
                  children: [
                    _SummaryTab(report: r),
                    _ProductsTab(report: r),
                    _TeamTab(report: r),
                    _StockTab(report: r),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRangeProvider);
    final now = DateTime.now();
    final presets = [
      ReportRange.today(now),
      ReportRange.lastDays(now, 7),
      ReportRange.lastDays(now, 14),
      ReportRange.thisMonth(now),
    ];
    final notifier = ref.read(selectedRangeProvider.notifier);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Gaps.md,
          vertical: Gaps.sm,
        ),
        children: [
          for (final p in presets) ...[
            ChoiceChip(
              label: Text(p.label),
              selected: selected == p,
              onSelected: (_) => notifier.range = p,
            ),
            const SizedBox(width: Gaps.sm),
          ],
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(
              presets.contains(selected) ? 'Elegir fechas' : selected.label,
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: now,
                initialDateRange: DateTimeRange(
                  start: selected.from,
                  end: selected.to.subtract(const Duration(days: 1)),
                ),
              );
              if (picked != null) {
                final f = DateFormat('d/M');
                notifier.range = ReportRange.days(
                  picked.start,
                  picked.end,
                  '${f.format(picked.start)} – ${f.format(picked.end)}',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryTab extends ConsumerStatefulWidget {
  const _SummaryTab({required this.report});

  final SalesReport report;

  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  Currency _currency = Currency.cup;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final s = r.summary;
    final costs =
        ref.watch(sessionProvider)?.can(Permission.viewCostsAndProfit) ?? false;
    final rate =
        ref.watch(pricingContextProvider).rate ?? ExchangeRate.units(1);
    final text = Theme.of(context).textTheme;

    if (s.salesCount == 0) {
      return const EmptyView(
        message: 'No hay ventas en este período.',
        icon: Icons.bar_chart,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth > 700 ? 4 : 2;
            final width = (c.maxWidth - Gaps.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.sm,
              children: [
                _Kpi(
                  width: width,
                  label: 'Ventas',
                  value: MoneyFormatter.format(s.totalCup),
                  detail: MoneyFormatter.format(s.totalUsd),
                ),
                _Kpi(
                  width: width,
                  label: 'Nº de ventas',
                  value: '${s.salesCount}',
                  detail: s.voidedCount == 0
                      ? 'Sin anulaciones'
                      : '${s.voidedCount} anuladas',
                ),
                _Kpi(
                  width: width,
                  label: 'Ticket promedio',
                  value: MoneyFormatter.format(s.averageTicketCup),
                  detail: MoneyFormatter.format(s.averageTicketUsd),
                ),
                if (costs)
                  _Kpi(
                    width: width,
                    label: 'Ganancia bruta',
                    value: MoneyFormatter.format(s.grossProfitUsd),
                    detail:
                        'Margen ${(s.marginBasisPoints / 100).toStringAsFixed(1)} %',
                    color: AppColors.success,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Gaps.lg),
        Row(
          children: [
            Expanded(child: Text('Ventas por día', style: text.titleMedium)),
            SegmentedButton<Currency>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Currency.cup, label: Text('CUP')),
                ButtonSegment(value: Currency.usd, label: Text('USD')),
              ],
              selected: {_currency},
              onSelectionChanged: (v) => setState(() => _currency = v.first),
            ),
          ],
        ),
        const SizedBox(height: Gaps.sm),
        DailySalesChart(daily: r.daily, currency: _currency),
        const SizedBox(height: Gaps.lg),
        Text('Formas de pago', style: text.titleMedium),
        const SizedBox(height: Gaps.sm),
        PaymentMethodsChart(totals: r.byPaymentMethod, toCup: rate.toCup),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    this.color,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelMedium),
              const SizedBox(height: Gaps.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Text(detail, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costs =
        ref.watch(sessionProvider)?.can(Permission.viewCostsAndProfit) ?? false;
    final top = report.top10;
    if (top.isEmpty) {
      return const EmptyView(message: 'No hay ventas en este período.');
    }
    final max = top.first.totalUsd.cents;
    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Text(
          'Top 10 por importe',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Gaps.sm),
        for (final (i, p) in top.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                    Text(MoneyFormatter.format(p.totalUsd)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : p.totalUsd.cents / max,
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    Qty.format(p.qtyMilli, p.unit),
                    MoneyFormatter.format(p.totalCup),
                    if (costs)
                      'Ganancia ${MoneyFormatter.format(p.grossProfitUsd)}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        const SizedBox(height: Gaps.md),
        Text(
          '${report.byProduct.length} productos vendidos en el período. '
          'Exporte a Excel/CSV para ver la lista completa.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    if (report.byCashier.isEmpty) {
      return const EmptyView(message: 'No hay ventas en este período.');
    }
    final total = report.byCashier.fold<int>(0, (a, c) => a + c.totalUsd.cents);
    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Text(
          'Ventas por cajero',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Gaps.sm),
        Card(
          child: Column(
            children: [
              for (final c in report.byCashier)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(c.cashierName.isEmpty ? '?' : c.cashierName[0]),
                  ),
                  title: Text(c.cashierName),
                  subtitle: Text(
                    '${c.salesCount} ventas · '
                    '${total == 0 ? 0 : (c.totalUsd.cents * 100 / total).toStringAsFixed(0)} % del total',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(MoneyFormatter.format(c.totalCup)),
                      Text(
                        MoneyFormatter.format(c.totalUsd),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    if (report.lowStock.isEmpty) {
      return const EmptyView(
        message: 'Ningún producto está por debajo del mínimo.',
        icon: Icons.check_circle_outline,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Text(
          '${report.lowStock.length} productos con bajo stock',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Gaps.sm),
        Card(
          child: Column(
            children: [
              for (final l in report.lowStock)
                ListTile(
                  leading: Icon(
                    l.stockMilli <= 0
                        ? Icons.error
                        : Icons.warning_amber_rounded,
                    color: l.stockMilli <= 0
                        ? AppColors.danger
                        : AppColors.warning,
                  ),
                  title: Text(l.name),
                  subtitle: Text(
                    'Hay ${Qty.format(l.stockMilli, l.unit)} · '
                    'mínimo ${Qty.format(l.minStockMilli, l.unit)}',
                  ),
                  trailing: Text(
                    'Pedir ${Qty.format(l.suggestedOrderMilli, l.unit)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () =>
                      context.push('${Routes.products}/${l.productId}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
