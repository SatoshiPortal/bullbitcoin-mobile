import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';

final class Bip48AccountDatasource {
  static const _keyPrefix = 'bip48_reserved_accounts_';

  final KeyValueStorageDatasource<String> _storage;

  const Bip48AccountDatasource(this._storage);

  Future<Set<int>> read({
    required String seedFingerprint,
    required int coinType,
  }) async {
    final value = await _storage.getValue(
      _key(seedFingerprint: seedFingerprint, coinType: coinType),
    );
    if (value == null) return {};
    return (jsonDecode(value) as List<dynamic>).cast<int>().toSet();
  }

  Future<void> write({
    required String seedFingerprint,
    required int coinType,
    required Set<int> accounts,
  }) => _storage.saveValue(
    key: _key(seedFingerprint: seedFingerprint, coinType: coinType),
    value: jsonEncode(accounts.toList()..sort()),
  );

  String _key({required String seedFingerprint, required int coinType}) =>
      '$_keyPrefix${seedFingerprint.toLowerCase()}_$coinType';
}
