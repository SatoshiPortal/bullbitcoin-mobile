import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/exchange_api_key_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';

/// Owns credential persistence and maps storage exceptions without logging their payload.
class ExchangeApiKeyRepositoryImpl implements ExchangeApiKeyRepository {
  final KeyValueStorageDatasource<String> _secureStorage;

  ExchangeApiKeyRepositoryImpl({required this._secureStorage});

  static String _storageKey(bool isTestnet) =>
      isTestnet ? 'exchange_api_key_testnet' : 'exchange_api_key';

  @override
  Future<Result<String?, ExchangeApiKeyFailure>> readActiveApiKey({
    required bool isTestnet,
  }) async {
    final String? stored;
    try {
      stored = await _secureStorage.getValue(_storageKey(isTestnet));
    } on Exception catch (error) {
      log.warning('Exchange credential unavailable: ${error.runtimeType}');
      return const Err(ExchangeApiKeyReadFailure());
    }
    if (stored == null || stored.isEmpty) return const Ok(null);
    try {
      // Authentication deliberately ignores account metadata and timestamps.
      return switch (jsonDecode(stored)) {
        {'key': final String key, 'isActive': final bool active}
            when ExchangeApiKey.isValidKey(key) =>
          Ok(active ? key : null),
        _ => const Err(ExchangeApiKeyInvalidFailure()),
      };
    } on FormatException {
      // FormatException embeds its source. Never log the exception itself.
      log.warning('Stored exchange credential is invalid');
      return const Err(ExchangeApiKeyInvalidFailure());
    }
  }

  @override
  Future<Result<void, ExchangeApiKeyFailure>> saveApiKey(
    ExchangeApiKey apiKey, {
    required bool isTestnet,
  }) async {
    try {
      final apiKeyModel = ExchangeApiKeyMapper.toModel(apiKey);

      await _secureStorage.saveValue(
        key: _storageKey(isTestnet),
        value: jsonEncode(apiKeyModel.toJson()),
      );
      return const Ok(null);
    } on Exception catch (e, st) {
      log.warning(
        'Failed to save the exchange API key',
        error: e.runtimeType,
        trace: st,
      );
      return Err(ExchangeApiKeySaveFailure('store failed: ${e.runtimeType}'));
    }
  }

  @override
  Future<Result<void, ExchangeApiKeyFailure>> deleteApiKey({
    required bool isTestnet,
  }) async {
    try {
      await _secureStorage.deleteValue(_storageKey(isTestnet));
      return const Ok(null);
    } on Exception catch (e, st) {
      log.warning(
        'Failed to delete the exchange API key',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        ExchangeApiKeyDeleteFailure('delete failed: ${e.runtimeType}'),
      );
    }
  }
}
