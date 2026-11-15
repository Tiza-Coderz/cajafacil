import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/features/demo/presentation/demo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mientras se generan las ventas de ejemplo, los módulos que dependen de
/// ellas (caja, POS, inventario, reportes) muestran una espera breve en vez
/// de datos a medias o turnos de caja en conflicto.
class DemoHistoryGate extends ConsumerWidget {
  const DemoHistoryGate({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(demoHistoryProvider);
    if (!history.running) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 48),
              const SizedBox(height: Gaps.md),
              const Text(
                'Preparando 2 semanas de ventas de ejemplo…',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gaps.md),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(value: history.progress),
              ),
              const SizedBox(height: Gaps.sm),
              if (history.total > 0)
                Text('Día ${history.day} de ${history.total}'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja informativa para la pantalla de inicio.
class DemoHistoryBanner extends ConsumerWidget {
  const DemoHistoryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(demoHistoryProvider);
    if (!history.running) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              history.total == 0
                  ? 'Generando ventas de ejemplo…'
                  : 'Generando ventas de ejemplo: día ${history.day} de '
                        '${history.total}',
            ),
            const SizedBox(height: Gaps.xs),
            LinearProgressIndicator(value: history.progress),
          ],
        ),
      ),
    );
  }
}
