import 'dart:typed_data';

import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/settings/data/settings_repository.dart';
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
Stream<BusinessProfile> businessProfile(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchProfile();

@Riverpod(keepAlive: true)
Stream<Uint8List?> businessLogo(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchLogo();
