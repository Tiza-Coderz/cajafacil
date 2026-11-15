import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Escanea un código de barras con la cámara y lo devuelve con
/// `Navigator.pop`. Incluye entrada manual por si la cámara no está
/// disponible o el código está dañado.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  static Future<String?> open(BuildContext context) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const BarcodeScannerScreen(),
        ),
      );

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
    ],
  );
  final _manual = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _finish(String? code) {
    final value = code?.trim() ?? '';
    if (_done || value.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear código'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) =>
                  _finish(capture.barcodes.firstOrNull?.rawValue),
              errorBuilder: (context, error) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Gaps.lg),
                  child: Text(
                    'No se pudo usar la cámara.\n'
                    'Escriba el código manualmente abajo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Gaps.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manual,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Escribir código',
                        isDense: true,
                      ),
                      onSubmitted: _finish,
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  FilledButton(
                    onPressed: () => _finish(_manual.text),
                    child: const Text('Usar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
