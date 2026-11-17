import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/config/env.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:cajafacil/core/sync/sync_controller.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:cajafacil/features/settings/presentation/cloud_link_dialog.dart';
import 'package:cajafacil/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Primer uso de un equipo sin usuarios (despliegue real, sin modo demo):
/// crear el negocio desde cero o vincularse a la nube y descargarlo.
class FirstRunSetup extends ConsumerWidget {
  const FirstRunSetup({super.key});

  Future<void> _createBusiness(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const _CreateDialog());

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final credentials = await showCloudLinkDialog(context);
    if (credentials == null) return;
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .link(email: credentials.email, password: credentials.password);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final sync = Env.canSync ? ref.watch(syncControllerProvider) : null;

    // Vinculado pero aún sin usuarios: la descarga está en curso o falló.
    if (sync != null && sync.linked) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.lg),
          child: Column(
            children: [
              if (sync.syncing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: Gaps.md),
                const Text(
                  'Descargando los datos del negocio…\n'
                  'Puede tardar unos minutos con conexión lenta.',
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  sync.error ?? 'La cuenta todavía no tiene datos.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.warning),
                ),
                const SizedBox(height: Gaps.md),
                FilledButton.icon(
                  onPressed: ref.read(syncControllerProvider.notifier).syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('Reintentar descarga'),
                ),
                TextButton(
                  onPressed: ref.read(syncControllerProvider.notifier).unlink,
                  child: const Text('Usar otra cuenta'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Configurar este equipo',
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gaps.sm),
        _Option(
          icon: Icons.storefront_outlined,
          title: 'Crear mi negocio',
          subtitle: 'Empiece desde cero en este equipo.',
          onTap: () => _createBusiness(context),
        ),
        if (Env.canSync) ...[
          const SizedBox(height: Gaps.sm),
          _Option(
            icon: Icons.cloud_download_outlined,
            title: 'Vincular con la nube',
            subtitle:
                'Si su negocio ya usa CajaFácil en otro equipo, descargue '
                'aquí sus productos, usuarios y ventas.',
            onTap: () => _link(context, ref),
          ),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _CreateDialog extends ConsumerStatefulWidget {
  const _CreateDialog();

  @override
  ConsumerState<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends ConsumerState<_CreateDialog> {
  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _pin = TextEditingController();
  final _pinAgain = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_business, _owner, _pin, _pinAgain, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_business.text.trim().isEmpty) return 'Escriba el nombre del negocio';
    if (_owner.text.trim().isEmpty) return 'Escriba su nombre';
    final pinError = PinRules.validate(_pin.text);
    if (pinError != null) return pinError;
    if (_pin.text != _pinAgain.text) return 'Los PIN no coinciden';
    final email = _email.text.trim();
    if (email.isNotEmpty) {
      if (!email.contains('@')) return 'El correo no es válido';
      if (_password.text.length < 6) {
        return 'La contraseña debe tener al menos 6 caracteres';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final email = _email.text.trim();
    await ref
        .read(settingsRepositoryProvider)
        .saveProfile(BusinessProfile(name: _business.text.trim()));
    final owner = await ref
        .read(authRepositoryProvider)
        .createUser(
          name: _owner.text.trim(),
          role: UserRole.owner,
          pin: _pin.text,
          email: email.isEmpty ? null : email,
          password: email.isEmpty ? null : _password.text,
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Listo. Toque "${owner.name}" y escriba su PIN para entrar.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear mi negocio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _business,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del negocio',
              ),
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _owner,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Su nombre y apellido (dueño)',
              ),
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: PinRules.length,
              decoration: const InputDecoration(
                labelText: 'PIN de ${PinRules.length} dígitos',
              ),
            ),
            TextField(
              controller: _pinAgain,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: PinRules.length,
              decoration: const InputDecoration(labelText: 'Repita el PIN'),
            ),
            const SizedBox(height: Gaps.sm),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo (opcional)',
                helperText: 'Para entrar también con correo y contraseña',
              ),
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña (si puso correo)',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gaps.md),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
