import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';
import 'package:cajafacil/features/auth/domain/repositories/auth_repository.dart';
import 'package:drift/drift.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._db, {SecretHasher hasher = const SecretHasher()})
    : _hasher = hasher;

  final AppDatabase _db;
  final SecretHasher _hasher;

  @override
  Stream<List<AppUser>> watchActiveUsers() {
    final query = _db.select(_db.users)
      ..where((u) => u.active.equals(true) & u.deletedAt.isNull())
      ..orderBy([(u) => OrderingTerm.asc(u.name)]);
    // Orden por jerarquía (dueño, encargado, cajero), no alfabético.
    return query.watch().map(
      (rows) =>
          rows.map(_toEntity).toList()
            ..sort((a, b) => a.role.index.compareTo(b.role.index)),
    );
  }

  @override
  Stream<List<AppUser>> watchAllUsers() {
    final query = _db.select(_db.users)
      ..where((u) => u.deletedAt.isNull())
      ..orderBy([(u) => OrderingTerm.asc(u.name)]);
    return query.watch().map(
      (rows) =>
          rows.map(_toEntity).toList()
            ..sort((a, b) => a.role.index.compareTo(b.role.index)),
    );
  }

  @override
  Future<void> setActive(String userId, {required bool active}) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(userId))).getSingle();
    if (!active && row.role == UserRole.owner) {
      final owners =
          await (_db.select(_db.users)..where(
                (u) =>
                    u.role.equalsValue(UserRole.owner) &
                    u.active.equals(true) &
                    u.deletedAt.isNull(),
              ))
              .get();
      if (owners.length <= 1) {
        throw const LastOwnerException();
      }
    }
    await _db.writeSynced(
      _db.users,
      row.copyWith(active: active, updatedAt: _db.clock.now()),
      entityId: userId,
    );
  }

  @override
  Future<AppUser?> verifyPin(String userId, String pin) async {
    final row =
        await (_db.select(_db.users)
              ..where((u) => u.id.equals(userId) & u.active.equals(true)))
            .getSingleOrNull();
    if (row == null || row.deletedAt != null) return null;
    return _hasher.verify(pin, row.pinSalt, row.pinHash)
        ? _toEntity(row)
        : null;
  }

  @override
  Future<AppUser?> verifyPassword(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final row =
        await (_db.select(_db.users)..where(
              (u) =>
                  u.email.equals(normalized) &
                  u.active.equals(true) &
                  u.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final hash = row?.passwordHash;
    if (row == null || hash == null) return null;
    // La contraseña usa la misma sal del usuario con un prefijo distinto.
    return _hasher.verify('pw:$password', row.pinSalt, hash)
        ? _toEntity(row)
        : null;
  }

  @override
  Future<AppUser> createUser({
    required String name,
    required UserRole role,
    required String pin,
    String? email,
    String? password,
  }) async {
    final now = _db.clock.now();
    final salt = _hasher.newSalt();
    final row = UserRow(
      id: _db.ids.newId(),
      createdAt: now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      name: name.trim(),
      email: email?.trim().toLowerCase(),
      role: role,
      pinSalt: salt,
      pinHash: _hasher.hash(pin, salt),
      passwordHash: password == null
          ? null
          : _hasher.hash('pw:$password', salt),
      active: true,
    );
    await _db.writeSynced(_db.users, row, entityId: row.id);
    return _toEntity(row);
  }

  @override
  Future<void> changePin(String userId, String newPin) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(userId))).getSingle();
    final updated = row.copyWith(
      pinHash: _hasher.hash(newPin, row.pinSalt),
      updatedAt: _db.clock.now(),
    );
    await _db.writeSynced(_db.users, updated, entityId: row.id);
  }

  AppUser _toEntity(UserRow row) => AppUser(
    id: row.id,
    name: row.name,
    role: row.role,
    email: row.email,
    active: row.active,
  );
}
