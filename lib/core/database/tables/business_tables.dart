import 'package:cajafacil/core/database/converters.dart';
import 'package:cajafacil/core/database/tables/sync_columns.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:drift/drift.dart';

/// Datos del negocio (fila única).
@DataClassName('BusinessSettingsRow')
class BusinessSettings extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get nit => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get whatsapp => text().withDefault(const Constant(''))();
  TextColumn get logoPath => text().nullable()();
  TextColumn get primaryCurrency =>
      textEnum<Currency>().withDefault(Constant(Currency.cup.name))();
  TextColumn get receiptFooter =>
      text().withDefault(const Constant('¡Gracias por su compra!'))();

  /// Redondeo de importes en CUP: 0, 1, 5 o 10 pesos.
  IntColumn get cupRoundingPesos => integer().withDefault(const Constant(5))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('UserRow')
class Users extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get email => text().nullable()();
  TextColumn get role => textEnum<UserRole>()();
  TextColumn get pinHash => text()();
  TextColumn get pinSalt => text()();

  /// Solo el dueño tiene contraseña (vincular dispositivo / acciones críticas).
  TextColumn get passwordHash => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table with SyncColumns {
  /// CUP x 100 por 1 USD (39000 = 390,00 CUP).
  IntColumn get cupPerUsdX100 =>
      // Patrón estándar de Drift para un CHECK sobre la propia columna.
      // ignore: recursive_getters
      integer().check(cupPerUsdX100.isBiggerThanValue(0))();
  IntColumn get effectiveDate => integer().map(const EpochMsConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get createdBy => text().references(Users, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
