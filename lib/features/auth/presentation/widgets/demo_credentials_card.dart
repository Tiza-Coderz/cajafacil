import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/features/demo/domain/demo_credentials.dart';
import 'package:flutter/material.dart';

/// Tarjeta visible solo en modo demo con los accesos de prueba.
class DemoCredentialsCard extends StatelessWidget {
  const DemoCredentialsCard({required this.onReset, super.key});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      color: AppColors.accent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: AppColors.warning),
                const SizedBox(width: Gaps.sm),
                Text('Modo demostración', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            const SelectableText(
              'Correo: ${DemoCredentials.ownerEmail}\n'
              'Contraseña: ${DemoCredentials.ownerPassword}',
            ),
            const SizedBox(height: Gaps.sm),
            for (final user in DemoCredentials.users)
              Text('• ${user.role.label}: PIN ${user.pin}'),
            const SizedBox(height: Gaps.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer demo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
