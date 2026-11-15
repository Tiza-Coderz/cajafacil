import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado numérico para PIN. Envía automáticamente al completar los
/// dígitos. También acepta el teclado físico (útil en la versión Web).
///
/// [onSubmit] devuelve un mensaje de error, o `null` si el PIN fue aceptado.
class PinPad extends StatefulWidget {
  const PinPad({required this.onSubmit, this.length = 4, super.key});

  final int length;
  final Future<String?> Function(String pin) onSubmit;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  final _focusNode = FocusNode();
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add(String digit) async {
    if (_busy || _pin.length >= widget.length) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == widget.length) {
      setState(() => _busy = true);
      final error = await widget.onSubmit(_pin);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error;
        if (error != null) _pin = '';
      });
    }
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _add(char);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'PIN: ${_pin.length} de ${widget.length} dígitos',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.all(Gaps.sm),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? scheme.primary : null,
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: Center(
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _error ?? '',
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Gaps.sm,
              crossAxisSpacing: Gaps.sm,
              childAspectRatio: 1.6,
              children: [
                for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                  _Key(label: d, onTap: () => _add(d)),
                const SizedBox.shrink(),
                _Key(label: '0', onTap: () => _add('0')),
                _Key(
                  icon: Icons.backspace_outlined,
                  semanticLabel: 'Borrar',
                  onTap: _backspace,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, this.label, this.icon, this.semanticLabel});

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: label != null
              ? Text(label!, style: Theme.of(context).textTheme.headlineSmall)
              : Icon(icon, semanticLabel: semanticLabel),
        ),
      ),
    );
  }
}
