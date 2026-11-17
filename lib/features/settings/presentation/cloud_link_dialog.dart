import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Pide el correo y la contraseña de la cuenta del dueño en la nube.
/// Devuelve null si el usuario cancela.
Future<({String email, String password})?> showCloudLinkDialog(
  BuildContext context,
) => showDialog<({String email, String password})>(
  context: context,
  builder: (_) => const _CloudLinkDialog(),
);

class _CloudLinkDialog extends StatefulWidget {
  const _CloudLinkDialog();

  @override
  State<_CloudLinkDialog> createState() => _CloudLinkDialogState();
}

class _CloudLinkDialogState extends State<_CloudLinkDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_email.text.contains('@') || _password.text.isEmpty) {
      setState(() => _error = 'Escriba el correo y la contraseña');
      return;
    }
    Navigator.pop(context, (
      email: _email.text.trim(),
      password: _password.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
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
        FilledButton(onPressed: _submit, child: const Text('Vincular')),
      ],
    );
  }
}
