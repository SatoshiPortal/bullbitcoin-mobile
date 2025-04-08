import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:flutter/foundation.dart';

class ApiKeyStorageDatasource {
  static const String _apiKeyStorageKey = 'exchange_api_key';

  final KeyValueStorageDatasource<String> _secureStorage;

  ApiKeyStorageDatasource({
    required KeyValueStorageDatasource<String> secureStorage,
  }) : _secureStorage = secureStorage;

  Future<void> store(ExchangeApiKeyModel apiKey) async {
    try {
      final jsonString = jsonEncode(apiKey.toJson());
      await _secureStorage.saveValue(
        key: _apiKeyStorageKey,
        value: jsonString,
      );
      debugPrint('API key stored successfully');
    } catch (e) {
      debugPrint('Error storing API key: $e');
      rethrow;
    }
  }

  Future<ExchangeApiKeyModel?> get() async {
    try {
      final jsonString = await _secureStorage.getValue(_apiKeyStorageKey);

      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('No API key found in storage');
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ExchangeApiKeyModel.fromJson(json);
    } catch (e) {
      debugPrint('Error retrieving API key: $e');
      return null;
    }
  }

  Future<void> delete() async {
    try {
      await _secureStorage.deleteValue(_apiKeyStorageKey);
      debugPrint('API key deleted successfully');
    } catch (e) {
      debugPrint('Error deleting API key: $e');
      rethrow;
    }
  }
}
