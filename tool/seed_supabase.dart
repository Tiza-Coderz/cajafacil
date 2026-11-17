// Carga los datos de prueba ("Mini-mercado La Esquina") en un proyecto de
// Supabase, en la cuenta del dueño. Los equipos que se vinculen con esa
// cuenta los descargan en el primer uso.
//
// Uso (desde la raíz del repo):
//   dart run tool/seed_supabase.dart             # lee .env.seed
//   dart run tool/seed_supabase.dart --dry-run   # solo genera y cuenta
//   dart run tool/seed_supabase.dart --force     # aunque la nube tenga datos
//   dart run tool/seed_supabase.dart --env-file=otra/ruta.env
//
// Ver docs/despliegue-cliente.md.
// Es una herramienta de consola: imprimir es su forma de comunicarse.
// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';

import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:cajafacil/core/sync/supabase_sync_api.dart';
import 'package:cajafacil/core/sync/sync_registry.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/cash_register/data/cash_register_repository_impl.dart';
import 'package:cajafacil/features/demo/data/demo_seeder.dart';
import 'package:cajafacil/features/demo/domain/demo_credentials.dart';
import 'package:cajafacil/features/exchange_rate/data/exchange_rate_repository_impl.dart';
import 'package:cajafacil/features/inventory/data/inventory_repository_impl.dart';
import 'package:cajafacil/features/pos/data/sale_repository_impl.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

const _batchSize = 200;

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } on SyncAuthException catch (e) {
    _fail('Supabase rechazó el acceso: $e');
  } on SyncNetworkException catch (e) {
    _fail('Problema de red con Supabase: $e');
  }
}

Future<void> _run(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final force = args.contains('--force');
  final envFile = args
      .firstWhere((a) => a.startsWith('--env-file='), orElse: () => '')
      .replaceFirst('--env-file=', '');
  final config = _loadConfig(envFile.isEmpty ? '.env.seed' : envFile);

  String need(String key) {
    final value = config[key] ?? '';
    if (value.isEmpty || value.contains('xxxx') || value.startsWith('su-')) {
      _fail(
        'Falta $key en el archivo de configuración (vea .env.seed.example).',
      );
    }
    return value;
  }

  SupabaseSyncApi? api;
  if (!dryRun) {
    final url = need('SUPABASE_URL').replaceAll(RegExp(r'/+$'), '');
    final anonKey = need('SUPABASE_ANON_KEY');
    print('→ Iniciando sesión como ${need('OWNER_EMAIL')}…');
    var session = await SupabaseSyncApi.signIn(
      baseUrl: url,
      anonKey: anonKey,
      email: need('OWNER_EMAIL'),
      password: need('OWNER_PASSWORD'),
    );
    api = SupabaseSyncApi(
      baseUrl: url,
      anonKey: anonKey,
      session: () => session,
      refresh: () async => session = await SupabaseSyncApi.refreshSession(
        baseUrl: url,
        anonKey: anonKey,
        refreshToken: session.refreshToken,
      ),
    );

    final existing = await api.pull(
      afterSeq: 0,
      excludeDeviceId: '-',
      limit: 1,
    );
    if (existing.records.isNotEmpty && !force) {
      _fail(
        'Esta cuenta ya tiene datos en la nube. Volver a sembrar duplicaría '
        'productos y usuarios.\nBorre antes los datos (vea "Empezar de cero" '
        'en docs/despliegue-cliente.md) o use --force si sabe lo que hace.',
      );
    }
  }

  print('→ Generando el negocio de ejemplo (2 semanas de ventas)…');
  _configureSqlite();
  final db = AppDatabase(NativeDatabase.memory());
  try {
    final ledger = StockLedger(db);
    final seeder = DemoSeeder(
      db,
      AuthRepositoryImpl(db),
      ExchangeRateRepositoryImpl(db),
      ProductRepositoryImpl(db, ledger),
      sales: SaleRepositoryImpl(db, ledger),
      cash: CashRegisterRepositoryImpl(db),
      inventory: InventoryRepositoryImpl(db, ledger),
    );
    await seeder.seed();
    await seeder.seedHistory(
      onProgress: (day, total) => stdout.write('\r   día $day de $total'),
    );
    stdout.writeln();

    final records = await snapshotAll(db);
    final perEntity = <String, int>{};
    for (final r in records) {
      perEntity.update(r.entity, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final MapEntry(:key, :value) in perEntity.entries) {
      print('   ${key.padRight(20)} $value');
    }
    print('   ${'TOTAL'.padRight(20)} ${records.length}');

    if (api == null) {
      print('✓ Prueba en seco: no se subió nada.');
      return;
    }

    print('→ Subiendo a Supabase…');
    for (var i = 0; i < records.length; i += _batchSize) {
      final end = (i + _batchSize).clamp(0, records.length);
      await _retry(() => api!.push(records.sublist(i, end)));
      stdout.write('\r   ${end * 100 ~/ records.length} %');
    }
    stdout.writeln();
    _printSummary(records.length);
  } finally {
    await db.close();
  }
}

void _printSummary(int count) {
  print('✓ Listo: $count registros en la nube.\n');
  print(
    'Vincule cada equipo en "Configurar este equipo → Vincular con la '
    'nube"\ncon el correo y la contraseña del dueño de Supabase. Usuarios '
    'de prueba:',
  );
  for (final u in DemoCredentials.users) {
    print('   ${u.name.padRight(20)} PIN ${u.pin}');
  }
}

/// La red desde Cuba falla a menudo: reintenta cada lote antes de rendirse.
Future<void> _retry(Future<void> Function() action) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await action();
    } on SyncNetworkException catch (e) {
      if (attempt == 4) rethrow;
      stdout.writeln('\n   reintento $attempt: ${e.message}');
      await Future<void>.delayed(Duration(seconds: 3 * attempt));
    }
  }
}

/// Lee KEY=VALUE del archivo (si existe); las variables de entorno mandan.
Map<String, String> _loadConfig(String path) {
  final file = File(path);
  final values = <String, String>{};
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq < 1) continue;
      values[trimmed.substring(0, eq).trim()] = trimmed
          .substring(eq + 1)
          .trim()
          .replaceAll(RegExp(r'''^["']|["']$'''), '');
    }
  }
  for (final key in [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'OWNER_EMAIL',
    'OWNER_PASSWORD',
  ]) {
    final env = Platform.environment[key];
    if (env != null && env.isNotEmpty) values[key] = env;
  }
  return values;
}

/// Windows no trae sqlite3.dll, pero sí winsqlite3.dll (igual que en tests).
void _configureSqlite() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (!Platform.isWindows) return;
  open.overrideFor(OperatingSystem.windows, () {
    try {
      return DynamicLibrary.open('sqlite3.dll');
      // DynamicLibrary.open lanza ArgumentError si no encuentra la DLL.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return DynamicLibrary.open('winsqlite3.dll');
    }
  });
}

Never _fail(String message) {
  stderr.writeln('✗ $message');
  exit(1);
}
