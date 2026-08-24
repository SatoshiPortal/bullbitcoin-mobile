import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';

class LedgerWalletPolicyHmacDatasource {
  final KeyValueStorageDatasource<String> _storage;

  const LedgerWalletPolicyHmacDatasource(this._storage);

  Future<void> save({
    required String walletId,
    required String signerId,
    required String policyId,
    required Uint8List hmac,
  }) => _storage.saveValue(
    key: _key(walletId, signerId, policyId),
    value: base64.encode(hmac),
  );

  Future<Uint8List?> get({
    required String walletId,
    required String signerId,
    required String policyId,
  }) async {
    final encoded = await _storage.getValue(_key(walletId, signerId, policyId));
    if (encoded == null) return null;
    try {
      final hmac = base64.decode(encoded);
      return hmac.length == 32 ? hmac : null;
    } on FormatException {
      return null;
    }
  }

  static String _key(String walletId, String signerId, String policyId) =>
      '${SecureStorageKeyPrefixConstants.ledgerWalletPolicyHmac}'
      '${walletId}_${signerId}_$policyId';
}
