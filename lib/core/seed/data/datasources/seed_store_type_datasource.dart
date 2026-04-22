import 'dart:convert';

import 'package:bb_mobile/core/seed/data/models/seed_store_type_model.dart';
import 'package:bb_mobile/core/utils/prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeedStoreTypeDatasource {
  static const _key = 'seed_store_type';

  const SeedStoreTypeDatasource();

  Future<SeedStoreTypeModel?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    final model = SeedStoreTypeModel.fromJson(json);
    // Backfill the mirror for users upgrading from a pre-mirror version so
    // [MigrationReporter.currentStorageState] reports the real FSS library
    // on that first launch instead of "unknown".
    if (prefs.getString(PrefsKeys.fssLibrary) == null) {
      await prefs.setString(
        PrefsKeys.fssLibrary,
        model.toEntity().storageLibrary.name,
      );
    }
    return model;
  }

  Future<void> write(SeedStoreTypeModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(model.toJson()));
    await prefs.setString(
      PrefsKeys.fssLibrary,
      model.toEntity().storageLibrary.name,
    );
  }
}
