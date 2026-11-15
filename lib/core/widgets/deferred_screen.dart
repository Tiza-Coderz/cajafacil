import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:flutter/material.dart';

/// Pantalla cuyo código se descarga solo al abrirla (`deferred as`).
///
/// En Web reduce el JavaScript inicial: reportes (gráficos, PDF) y ajustes
/// no se bajan hasta que alguien los usa. Clave con conexiones lentas.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    required this.title,
    required this.load,
    required this.builder,
    super.key,
  });

  final String title;
  final Future<void> Function() load;
  final WidgetBuilder builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _loading = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: snapshot.hasError
              ? ErrorView(
                  message:
                      'No se pudo descargar esta sección. '
                      'Revise la conexión e intente de nuevo.',
                  onRetry: () => setState(() => _loading = widget.load()),
                )
              : const LoadingView(message: 'Cargando…'),
        );
      },
    );
  }
}
