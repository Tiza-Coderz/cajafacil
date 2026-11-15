import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/config/env.dart';
import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:cajafacil/core/sync/sync_controller.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado y acciones de la sincronización en la nube (opcional).
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular con la nube'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use la cuenta del dueño. Todos los equipos vinculados a la '
              'misma cuenta comparten ventas, productos e inventario.',
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      try {
        await ref
            .read(syncControllerProvider.notifier)
            .link(email: email.text, password: password.text);
      } on Object catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is SyncAuthException || e is SyncNetworkException
                    ? e.toString()
                    : 'No se pudo vincular.',
              ),
            ),
          );
        }
      }
    }
    email.dispose();
    password.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.canSync) return const SizedBox.shrink();
    final status = ref.watch(syncControllerProvider);
    final notifier = ref.read(syncControllerProvider.notifier);
    final subtitle = !status.linked
        ? 'Este equipo trabaja solo (sin nube).'
        : [
            if (status.lastSyncAt != null)
              'Última: ${AppDates.relativeDayTime(status.lastSyncAt!)}',
            '${status.pending} cambios pendientes',
          ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  status.linked ? Icons.cloud_done_outlined : Icons.cloud_off,
                  color: status.linked ? AppColors.success : null,
                ),
                const SizedBox(width: Gaps.sm),
                Text(
                  'Sincronización',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            Text(subtitle),
            if (status.error != null) ...[
              const SizedBox(height: Gaps.xs),
              Text(
                status.error!,
                style: const TextStyle(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: Gaps.md),
            if (!status.linked)
              FilledButton.icon(
                onPressed: () => _link(context, ref),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Vincular con la nube'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: status.syncing ? null : notifier.syncNow,
                      icon: status.syncing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Sincronizar ahora'),
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  TextButton(
                    onPressed: notifier.unlink,
                    child: const Text('Desvincular'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
