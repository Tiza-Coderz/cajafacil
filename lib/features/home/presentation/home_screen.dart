import 'package:cajafacil/app/router/app_modules.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/demo/presentation/demo_history_gate.dart';
import 'package:cajafacil/features/exchange_rate/presentation/providers/exchange_rate_providers.dart';
import 'package:cajafacil/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Menú principal: muestra solo los módulos que el rol puede usar.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final modules = appModules.where((m) => user.can(m.permission)).toList();
    final business = ref.watch(businessProfileProvider).value;
    final rate = ref.watch(currentRateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(business?.name ?? 'CajaFácil'),
            Text(
              'Hola, ${user.name.split(' ').first} · ${user.role.label}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (rate != null)
            Padding(
              padding: const EdgeInsets.only(right: Gaps.xs),
              child: Center(
                child: Tooltip(
                  message: 'Tasa del día',
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.currency_exchange, size: 16),
                    label: Text(
                      '${rate.rate.cupPerUsdX100 ~/ 100} CUP',
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoHistoryBanner(),
          Expanded(child: _ModulesGrid(modules: modules)),
        ],
      ),
    );
  }
}

class _ModulesGrid extends StatelessWidget {
  const _ModulesGrid({required this.modules});

  final List<AppModule> modules;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 220).floor().clamp(2, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(Gaps.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: Gaps.md,
            crossAxisSpacing: Gaps.md,
            childAspectRatio: 1.1,
          ),
          itemCount: modules.length,
          itemBuilder: (context, i) => _ModuleCard(module: modules[i]),
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(module.route),
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.primary,
                child: Icon(module.icon),
              ),
              const Spacer(),
              Text(module.title, style: text.titleMedium),
              Text(
                module.description,
                style: text.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
