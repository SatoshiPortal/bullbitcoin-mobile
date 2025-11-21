import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// We don't need a full datasource since we only need to retrieve the API key
// here. We should deprecate the BullbitcoinApiKeyDatasource in favor of this
// simpler provider.
class BullbitcoinApiKeyProvider {
  final FlutterSecureStorage _secureStorage;

  static const String _apiKeyStorageKey = 'exchange_api_key';
  static const String _apiKeyTestnetStorageKey = 'exchange_api_key_testnet';

  BullbitcoinApiKeyProvider({required FlutterSecureStorage secureStorage})
    : _secureStorage = secureStorage;

  Future<String?> getApiKey({required bool isTestnet}) async {
    try {
      final key = isTestnet ? _apiKeyTestnetStorageKey : _apiKeyStorageKey;
      final jsonString = await _secureStorage.read(key: key);

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
      log.severe('Error retrieving API key: $e');
      return null;
    }
  }
}
