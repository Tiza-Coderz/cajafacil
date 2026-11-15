import 'dart:ffi';
import 'dart:io';

import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

var _sqliteConfigured = false;

/// BD SQLite en memoria para tests de repositorios y servicios.
AppDatabase createTestDatabase({Clock? clock}) {
  _configureSqlite();
  return AppDatabase(NativeDatabase.memory(), clock: clock ?? const Clock());
}

void _configureSqlite() {
  if (_sqliteConfigured) return;
  _sqliteConfigured = true;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (Platform.isWindows) {
    // `flutter test` no incluye sqlite3.dll; Windows 10+ trae winsqlite3.dll.
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
}
