import 'dart:async';

import 'package:cajafacil/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Punto de arranque común: inicializa locale, captura errores no manejados
/// y monta el árbol de providers.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error no manejado: $error\n$stack');
    return true;
  };

  runApp(const ProviderScope(child: CajaFacilApp()));
}
