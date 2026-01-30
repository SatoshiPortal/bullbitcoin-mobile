import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class BullbitcoinApiKeyProvider {
  final KeyValueStorageDatasource<String> _secureStorage;

  static const String _apiKeyStorageKey = 'exchange_api_key';
  static const String _apiKeyTestnetStorageKey = 'exchange_api_key_testnet';

  BullbitcoinApiKeyProvider({
    required KeyValueStorageDatasource<String> secureStorage,
  }) : _secureStorage = secureStorage;

  Future<String?> getApiKey({required bool isTestnet}) async {
    try {
      final key = isTestnet ? _apiKeyTestnetStorageKey : _apiKeyStorageKey;
      final jsonString = await _secureStorage.getValue(key);

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final apiKeyModel = ExchangeApiKeyModel.fromJson(json);

      // Validate before returning
      if (!apiKeyModel.isActive) {
        throw Exception(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      return apiKeyModel.key;
    } catch (e) {
      log.severe(
        message: 'Error retrieving API key',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }
}
