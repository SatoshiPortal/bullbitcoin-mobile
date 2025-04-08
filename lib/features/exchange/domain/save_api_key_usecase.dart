import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/datasources/api_key_storage_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:flutter/foundation.dart';

/// Usecase to save API key from JSON response to secure storage
class SaveApiKeyUsecase {
  final ApiKeyStorageDatasource apiKeyStorage;

  SaveApiKeyUsecase({
    required this.apiKeyStorage,
  });

  Future<bool> execute(String jsonResponse) async {
    try {
      final Map<String, dynamic> responseData =
          json.decode(jsonResponse) as Map<String, dynamic>;

      Map<String, dynamic> apiKeyData;

      // Check various formats the API might return
      if (responseData.containsKey('apiKey')) {
        // Format: { "apiKey": { ... } }
        apiKeyData = responseData['apiKey'] as Map<String, dynamic>;
      } else if (responseData.containsKey('result') &&
          responseData['result'] is Map &&
          (responseData['result'] as Map).containsKey('apiKey')) {
        // Format: { "result": { "apiKey": { ... } } }
        apiKeyData = responseData['result']['apiKey'] as Map<String, dynamic>;
      } else if (responseData.containsKey('data') &&
          responseData['data'] is Map &&
          (responseData['data'] as Map).containsKey('apiKey')) {
        // Format: { "data": { "apiKey": { ... } } }
        apiKeyData = responseData['data']['apiKey'] as Map<String, dynamic>;
      } else {
        apiKeyData = responseData;
      }

      final apiKeyModel = ExchangeApiKeyModel.fromJson(apiKeyData);

      await apiKeyStorage.store(apiKeyModel);

      debugPrint('API key saved successfully: ${apiKeyModel.id}');
      return true;
    } catch (e) {
      debugPrint('Error in SaveApiKeyUsecase: $e');
      return false;
    }
  }
}
