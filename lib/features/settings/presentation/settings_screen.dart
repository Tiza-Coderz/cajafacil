import 'dart:typed_data';

import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/config/env.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/core/utils/image_compressor.dart';
import 'package:cajafacil/core/utils/whatsapp.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';
import 'package:cajafacil/features/auth/domain/repositories/auth_repository.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/demo/presentation/demo_providers.dart';
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:cajafacil/features/settings/presentation/settings_providers.dart';
import 'package:cajafacil/features/settings/presentation/sync_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(businessProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            const ErrorView(message: 'No se pudieron leer los ajustes.'),
        data: (p) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(Gaps.md),
              children: [
                _BusinessForm(profile: p),
                const SizedBox(height: Gaps.lg),
                const _UsersSection(),
                const SizedBox(height: Gaps.lg),
                const SyncSection(),
                const SizedBox(height: Gaps.lg),
                const _SupportSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessForm extends ConsumerStatefulWidget {
  const _BusinessForm({required this.profile});

  final BusinessProfile profile;

  @override
  ConsumerState<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends ConsumerState<_BusinessForm> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _address = TextEditingController(text: widget.profile.address);
  late final _nit = TextEditingController(text: widget.profile.nit);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _whatsapp = TextEditingController(text: widget.profile.whatsapp);
  late final _footer = TextEditingController(
    text: widget.profile.receiptFooter,
  );
  late Currency _currency = widget.profile.primaryCurrency;
  late CupRounding _rounding = widget.profile.cupRounding;
  Uint8List? _logo;
  bool _logoLoaded = false;
  String? _nameError;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _address, _nit, _phone, _whatsapp, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    if (file == null) return;
    final thumb = ImageCompressor.thumbnail(await file.readAsBytes());
    if (thumb != null) setState(() => _logo = thumb);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Escriba el nombre del negocio');
      return;
    }
    final nit = _nit.text.trim();
    if (nit.isNotEmpty && !RegExp(r'^\d{11}$').hasMatch(nit)) {
      setState(() => _nameError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El NIT debe tener 11 dígitos.')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    await ref
        .read(settingsRepositoryProvider)
        .saveProfile(
          widget.profile.copyWith(
            name: _name.text,
            address: _address.text,
            nit: nit,
            phone: _phone.text,
            whatsapp: _whatsapp.text,
            receiptFooter: _footer.text,
            primaryCurrency: _currency,
            cupRounding: _rounding,
            logo: _logo,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(content: Text('Datos del negocio guardados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storedLogo = ref.watch(businessLogoProvider).value;
    if (!_logoLoaded && storedLogo != null) {
      _logo = storedLogo;
      _logoLoaded = true;
    }
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Datos del negocio', style: text.titleMedium),
            const SizedBox(height: Gaps.md),
            Row(
              children: [
                InkWell(
                  onTap: _pickLogo,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _logo == null
                        ? const Icon(Icons.add_a_photo_outlined)
                        : Image.memory(_logo!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: 'Nombre del negocio *',
                      errorText: _nameError,
                    ),
                  ),
                ),
              ],
            ),
            if (_logo != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _logo = null),
                  child: const Text('Quitar logo'),
                ),
              ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Calle, número, entre calles, municipio',
              ),
            ),
            const SizedBox(height: Gaps.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'NIT'),
                  ),
                ),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp del negocio',
                hintText: 'Ej.: 5352345678',
                helperText: 'Formato internacional sin "+"',
              ),
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _footer,
              decoration: const InputDecoration(
                labelText: 'Mensaje al pie del ticket',
              ),
            ),
            const SizedBox(height: Gaps.lg),
            Text('Moneda principal', style: text.titleSmall),
            const SizedBox(height: Gaps.xs),
            const Text(
              'La que se muestra en grande en el punto de venta. Los precios '
              'base siempre se guardan en USD.',
            ),
            const SizedBox(height: Gaps.sm),
            SegmentedButton<Currency>(
              segments: [
                for (final c in Currency.values)
                  ButtonSegment(value: c, label: Text(c.label)),
              ],
              selected: {_currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: Gaps.lg),
            Text('Redondeo de importes en CUP (pesos)', style: text.titleSmall),
            const SizedBox(height: Gaps.sm),
            SegmentedButton<CupRounding>(
              segments: const [
                ButtonSegment(value: CupRounding.none, label: Text('Exacto')),
                ButtonSegment(value: CupRounding.one, label: Text('1')),
                ButtonSegment(value: CupRounding.five, label: Text('5')),
                ButtonSegment(value: CupRounding.ten, label: Text('10')),
              ],
              selected: {_rounding},
              onSelectionChanged: (s) => setState(() => _rounding = s.first),
            ),
            const SizedBox(height: Gaps.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersSection extends ConsumerWidget {
  const _UsersSection();

  Future<void> _addUser(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<(String, UserRole, String)>(
      context: context,
      builder: (_) => const _UserDialog(),
    );
    if (result == null) return;
    await ref
        .read(authRepositoryProvider)
        .createUser(name: result.$1, role: result.$2, pin: result.$3);
  }

  Future<void> _changePin(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(userName: user.name),
    );
    if (pin == null) return;
    await ref.read(authRepositoryProvider).changePin(user.id, pin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN de ${user.name} actualizado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider);
    final me = ref.watch(sessionProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Usuarios',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addUser(context, ref),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Añadir'),
                ),
              ],
            ),
            users.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('No se pudieron cargar.'),
              data: (list) => Column(
                children: [
                  for (final u in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text(u.initials)),
                      title: Text(
                        u.name,
                        style: TextStyle(
                          color: u.active
                              ? null
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                      subtitle: Text(
                        u.active ? u.role.label : '${u.role.label} · Inactivo',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opciones',
                        onSelected: (action) async {
                          if (action == 'pin') {
                            await _changePin(context, ref, u);
                          } else {
                            try {
                              await ref
                                  .read(authRepositoryProvider)
                                  .setActive(u.id, active: !u.active);
                            } on LastOwnerException catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'pin',
                            child: Text('Cambiar PIN'),
                          ),
                          if (u.id != me?.id)
                            PopupMenuItem(
                              value: 'active',
                              child: Text(u.active ? 'Desactivar' : 'Activar'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog();

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  UserRole _role = UserRole.cashier;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escriba el nombre');
      return;
    }
    final pinError = PinRules.validate(_pin.text);
    if (pinError != null) {
      setState(() => _error = pinError);
      return;
    }
    Navigator.pop(context, (_name.text.trim(), _role, _pin.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo usuario'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre y apellido'),
          ),
          const SizedBox(height: Gaps.md),
          DropdownButtonFormField<UserRole>(
            value: _role,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: [
              for (final r in UserRole.values)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (r) => setState(() => _role = r ?? _role),
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: PinRules.length,
            decoration: InputDecoration(
              labelText: 'PIN de ${PinRules.length} dígitos',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Crear')),
      ],
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.userName});

  final String userName;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final error = PinRules.validate(_pin.text);
    if (error != null) {
      setState(() => _error = error);
    } else if (_pin.text != _confirm.text) {
      setState(() => _error = 'Los PIN no coinciden');
    } else {
      Navigator.pop(context, _pin.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nuevo PIN para ${widget.userName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinRules.length,
            decoration: const InputDecoration(labelText: 'PIN nuevo'),
          ),
          TextField(
            controller: _confirm,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinRules.length,
            decoration: InputDecoration(
              labelText: 'Repita el PIN',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _SupportSection extends ConsumerWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.chat_outlined, color: AppColors.whatsapp),
            title: const Text('Soporte por WhatsApp'),
            subtitle: const Text('Dudas, capacitación o nuevas funciones'),
            onTap: () => WhatsApp.open(
              phone: Env.supportWhatsapp,
              text: 'Hola, le escribo desde CajaFácil. Necesito ayuda con…',
            ),
          ),
          if (Env.demoMode)
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Restablecer demo'),
              subtitle: const Text('Vuelve a cargar los datos de ejemplo'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('¿Restablecer la demo?'),
                    content: const Text(
                      'Se borrarán todos los cambios y se cerrará la sesión.',
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
                if (ok ?? false) {
                  ref.read(sessionProvider.notifier).logout();
                  await ref.read(demoHistoryProvider.notifier).reset();
                }
              },
            ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('CajaFácil'),
            subtitle: Text(
              'Funciona sin conexión · Datos guardados en este equipo',
            ),
          ),
        ],
      ),
    );
  }
}
