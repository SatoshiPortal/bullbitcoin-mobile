import 'dart:convert';

import 'package:bb_mobile/core/seed/data/models/seed_store_type_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeedStoreTypeDatasource {
  static const _key = 'seed_store_type';

  const SeedStoreTypeDatasource();

  Future<SeedStoreTypeModel?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    return SeedStoreTypeModel.fromJson(json);
  }

  Future<void> write(SeedStoreTypeModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(model.toJson()));
  }
}
