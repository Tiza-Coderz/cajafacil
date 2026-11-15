import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/utils/whatsapp.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/pos/domain/entities/sale_receipt.dart';
import 'package:cajafacil/features/pos/domain/services/receipt_formatter.dart';
import 'package:cajafacil/features/pos/presentation/providers/cart_controller.dart';
import 'package:cajafacil/features/pos/presentation/receipt/receipt_pdf.dart'
    deferred as receipt_pdf;
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:cajafacil/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart' deferred as printing;

/// Ticket en pantalla con opciones de PDF/impresión y WhatsApp.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({required this.saleId, super.key});

  final String saleId;

  ReceiptHeader _header(BusinessProfile p) => ReceiptHeader(
    businessName: p.name,
    address: p.address,
    nit: p.nit,
    phone: p.phone,
    footer: p.receiptFooter,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(saleReceiptProvider(saleId));
    final profile =
        ref.watch(businessProfileProvider).value ?? BusinessProfile.fallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () => context.go(Routes.pos),
          ),
        ],
      ),
      body: receipt.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            const ErrorView(message: 'No se pudo cargar el ticket.'),
        data: (r) {
          if (r == null) {
            return const EmptyView(message: 'La venta no existe.');
          }
          final header = _header(profile);
          final text = ReceiptFormatter.plainText(r, header);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(Gaps.md),
                children: [
                  if (!r.isVoided)
                    const ListTile(
                      leading: Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 36,
                      ),
                      title: Text('Venta registrada'),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gaps.md),
                      child: SelectableText(
                        text.replaceAll('*', ''),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gaps.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pdf(context, r, header),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('PDF / Imprimir'),
                        ),
                      ),
                      const SizedBox(width: Gaps.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.whatsapp,
                          ),
                          onPressed: () => WhatsApp.open(text: text),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gaps.md),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => context.go(Routes.pos),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Nueva venta'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pdf(
    BuildContext context,
    SaleReceipt r,
    ReceiptHeader header,
  ) async {
    // El generador de PDF se descarga solo cuando se pide (carga diferida).
    await Future.wait([receipt_pdf.loadLibrary(), printing.loadLibrary()]);
    final bytes = await receipt_pdf.ReceiptPdf.build(r, header);
    await printing.Printing.layoutPdf(
      name: 'ticket-${r.number}.pdf',
      onLayout: (_) async => bytes,
    );
  }
}
