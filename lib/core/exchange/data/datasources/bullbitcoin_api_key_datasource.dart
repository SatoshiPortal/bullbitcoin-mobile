import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;

class BullbitcoinApiKeyDatasource {
  static const String _apiKeyStorageKey = 'exchange_api_key';
  static const String _apiKeyTestnetStorageKey = 'exchange_api_key_testnet';
  static const String _sellToFiatBalanceApiKeyStorageKey =
      'sell_to_fiat_balance_api_key';
  static const String _sellToFiatBalanceApiKeyTestnetStorageKey =
      'sell_to_fiat_balance_api_key_testnet';

  final KeyValueStorageDatasource<String> _secureStorage;

  BullbitcoinApiKeyDatasource({required this._secureStorage});

  Future<void> store(
    ExchangeApiKeyModel apiKey, {
    required bool isTestnet,
  }) async {
    try {
      final jsonString = jsonEncode(apiKey.toJson());
      final key = isTestnet ? _apiKeyTestnetStorageKey : _apiKeyStorageKey;
      await _secureStorage.saveValue(key: key, value: jsonString);
      log.fine('Exchange API key stored successfully');
    } catch (_) {
      log.warning('Unable to store Bull Bitcoin API key');
      rethrow;
    }
  }

  Future<void> storeSellToFiatBalanceApiKey(
    String apiKey, {
    required bool isTestnet,
  }) async {
    try {
      final key = isTestnet
          ? _sellToFiatBalanceApiKeyTestnetStorageKey
          : _sellToFiatBalanceApiKeyStorageKey;
      await _secureStorage.saveValue(key: key, value: apiKey);
      log.fine('Scoped API key stored successfully');
    } catch (_) {
      log.warning('Unable to store scoped Bull Bitcoin API key');
      rethrow;
    }
  }

  Future<ExchangeApiKeyModel?> get({required bool isTestnet}) async {
    try {
      final key = isTestnet ? _apiKeyTestnetStorageKey : _apiKeyStorageKey;
      final jsonString = await _secureStorage.getValue(key);

      if (jsonString == null || jsonString.isEmpty) {
        log.warning('User not logged in exchange (no API key)');
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ExchangeApiKeyModel.fromJson(json);
    } catch (_) {
      log.warning('Unable to retrieve Bull Bitcoin API key');
      return null;
    }
  }

  Future<void> delete({required bool isTestnet}) async {
    try {
      final key = isTestnet ? _apiKeyTestnetStorageKey : _apiKeyStorageKey;
      await _secureStorage.deleteValue(key);
      log.fine('API key deleted successfully');
    } catch (_) {
      log.warning('Unable to delete Bull Bitcoin API key');
      rethrow;
    }
  }

  Future<void> deleteSellToFiatBalanceApiKey({required bool isTestnet}) async {
    try {
      final key = isTestnet
          ? _sellToFiatBalanceApiKeyTestnetStorageKey
          : _sellToFiatBalanceApiKeyStorageKey;
      await _secureStorage.deleteValue(key);
      log.fine('Scoped API key deleted successfully');
    } catch (_) {
      log.warning('Unable to delete scoped Bull Bitcoin API key');
      rethrow;
    }
  }
}
