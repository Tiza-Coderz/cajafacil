import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/config/env.dart';
import 'package:cajafacil/core/widgets/pin_pad.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/auth/presentation/widgets/demo_credentials_card.dart';
import 'package:cajafacil/features/auth/presentation/widgets/login_feedback.dart';
import 'package:cajafacil/features/auth/presentation/widgets/password_login_dialog.dart';
import 'package:cajafacil/features/auth/presentation/widgets/user_tile.dart';
import 'package:cajafacil/features/demo/presentation/demo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _askPin(BuildContext context, WidgetRef ref, AppUser user) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hola, ${user.name.split(' ').first}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: Gaps.xs),
              const Text('Escriba su PIN de 4 dígitos'),
              const SizedBox(height: Gaps.md),
              PinPad(
                onSubmit: (pin) async {
                  final result = await ref
                      .read(sessionProvider.notifier)
                      .loginWithPin(user, pin);
                  final error = loginErrorMessage(result);
                  if (error == null && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  return error;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resetDemo(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restablecer la demo?'),
        content: const Text(
          'Se borrarán todos los cambios y se cargarán de nuevo los datos '
          'de ejemplo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(demoHistoryProvider.notifier).reset();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo restablecida.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(activeUsersProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gaps.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.point_of_sale,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: Gaps.sm),
                  Text(
                    'CajaFácil',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ventas, inventario y caja para su negocio',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: Gaps.lg),
                  Text('¿Quién va a trabajar?', style: text.titleMedium),
                  const SizedBox(height: Gaps.sm),
                  users.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(Gaps.lg),
                      child: LoadingView(),
                    ),
                    error: (e, _) => ErrorView(
                      message: 'No se pudieron cargar los usuarios.',
                      onRetry: () => ref.invalidate(activeUsersProvider),
                    ),
                    data: (list) => list.isEmpty
                        ? const EmptyView(
                            message: 'No hay usuarios registrados.',
                            icon: Icons.person_off_outlined,
                          )
                        : Column(
                            children: [
                              for (final user in list)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: Gaps.sm,
                                  ),
                                  child: UserTile(
                                    user: user,
                                    onTap: () => _askPin(context, ref, user),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const PasswordLoginDialog(),
                    ),
                    icon: const Icon(Icons.alternate_email),
                    label: const Text('Entrar con correo y contraseña'),
                  ),
                  if (Env.demoMode) ...[
                    const SizedBox(height: Gaps.md),
                    DemoCredentialsCard(
                      onReset: () => _resetDemo(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
