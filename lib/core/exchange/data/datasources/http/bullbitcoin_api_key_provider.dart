import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bull_logger/bull_logger.dart';

/// Reads the current active credential at point of use, without caching it.
class BullbitcoinApiKeyProvider {
  static const _mainnetKey = 'exchange_api_key';
  static const _testnetKey = 'exchange_api_key_testnet';

  final KeyValueStorageDatasource<String> _secureStorage;

  BullbitcoinApiKeyProvider({required this._secureStorage});

  Future<String?> getApiKey({required bool isTestnet}) async {
    try {
      final stored = await _secureStorage.getValue(
        isTestnet ? _testnetKey : _mainnetKey,
      );
      if (stored == null || stored.isEmpty) return null;
      // Authentication needs only the active flag and header value. Validate
      // those fields explicitly rather than casting untrusted storage data.
      return switch (jsonDecode(stored)) {
        {'isActive': true, 'key': final String key} => key,
        _ => null,
      };
    } on Exception catch (error, trace) {
      // FormatException includes its source, which may contain the API key.
      log.severe(
        message: 'Error retrieving API key',
        error: error.runtimeType,
        trace: trace,
      );
      return null;
    }
  }
}
