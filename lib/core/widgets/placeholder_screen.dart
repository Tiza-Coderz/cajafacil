import 'package:flutter/material.dart';

/// Pantalla temporal para rutas aún no implementadas.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('En construcción')),
    );
  }
}
