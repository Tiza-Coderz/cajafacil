import 'dart:convert';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:drift/drift.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _rowId = 'business';

  Stream<BusinessProfile> watchProfile() {
    final query = _db.select(_db.businessSettings)
      ..where((b) => b.id.equals(_rowId));
    return query.watchSingleOrNull().map(
      (row) => row == null ? BusinessProfile.fallback : _map(row),
    );
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    final now = _db.clock.now();
    final existing = await (_db.select(
      _db.businessSettings,
    )..where((b) => b.id.equals(_rowId))).getSingleOrNull();
    final row = BusinessSettingsRow(
      id: _rowId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      name: profile.name.trim(),
      address: profile.address.trim(),
      nit: profile.nit.trim(),
      phone: profile.phone.trim(),
      whatsapp: profile.whatsapp.trim(),
      logoPath: existing?.logoPath,
      primaryCurrency: profile.primaryCurrency,
      receiptFooter: profile.receiptFooter.trim(),
      cupRoundingPesos: profile.cupRounding.pesos,
    );
    await _db.writeSynced(_db.businessSettings, row, entityId: _rowId);
    await _saveLogo(profile.logo);
  }

  // El logo se guarda aparte en sync_state para no inflar el payload de
  // sincronización de la fila del negocio en cada cambio.
  static const _logoKey = 'business_logo_b64';

  Future<void> _saveLogo(Uint8List? logo) async {
    if (logo == null) {
      await (_db.delete(
        _db.syncState,
      )..where((s) => s.key.equals(_logoKey))).go();
      return;
    }
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(key: _logoKey, value: _encode(logo)),
        );
  }

  Stream<Uint8List?> watchLogo() {
    final query = _db.select(_db.syncState)
      ..where((s) => s.key.equals(_logoKey));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _decode(row.value),
    );
  }

  static String _encode(Uint8List bytes) => base64Encode(bytes);

  static Uint8List _decode(String value) => base64Decode(value);

  BusinessProfile _map(BusinessSettingsRow row) => BusinessProfile(
    name: row.name,
    address: row.address,
    nit: row.nit,
    phone: row.phone,
    whatsapp: row.whatsapp,
    primaryCurrency: row.primaryCurrency,
    receiptFooter: row.receiptFooter,
    cupRounding: CupRounding.fromPesos(row.cupRoundingPesos),
  );
}
