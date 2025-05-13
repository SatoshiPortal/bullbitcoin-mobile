import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';

Future<OldSeed> fetchOldSeed({
  required OldSecureStorage secureStorage,
  required String fingerprintIndex,
}) async {
  final jsn = await secureStorage.getValue(fingerprintIndex);
  if (jsn == null) {
    throw Exception('No seed found');
  }
  final obj = jsonDecode(jsn) as Map<String, dynamic>;
  final seed = OldSeed.fromJson(obj);
  return seed;
}
