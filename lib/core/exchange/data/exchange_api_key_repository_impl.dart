import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';

/// The `try/catch` boundary for the stored session.
///
/// Nothing logged here may carry key material: the payload is the auth
/// response, so only the exception type is recorded.
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
            when key.isNotEmpty =>
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
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  }) async {
    try {
      final apiKeyModel = ExchangeApiKeyModel.fromJson(
        _unwrapApiKeyPayload(apiKeyResponseData),
      );

      await _secureStorage.saveValue(
        key: _storageKey(isTestnet),
        value: jsonEncode(apiKeyModel.toJson()),
      );
      return const Ok(null);
    } catch (e, st) {
      // Also catches the TypeError fromJson throws on a malformed envelope.
      // That is an Error by the project's taxonomy, but the envelope is
      // untrusted auth-app input, so it is validated here at the boundary.
      // Type only — never the payload, which is session material.
      log.severe(
        message: 'Failed to save the exchange API key',
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
    } catch (e, st) {
      log.severe(
        message: 'Failed to delete the exchange API key',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        ExchangeApiKeyDeleteFailure('delete failed: ${e.runtimeType}'),
      );
    }
  }

  /// The auth app has shipped several envelope shapes over time; accept them
  /// all rather than failing on a wrapper key.
  Map<String, dynamic> _unwrapApiKeyPayload(Map<String, dynamic> response) {
    if (response['apiKey'] case final Map<String, dynamic> apiKey) {
      return apiKey;
    }
    if (response['result'] case final Map<String, dynamic> result) {
      if (result['apiKey'] case final Map<String, dynamic> apiKey) {
        return apiKey;
      }
    }
    if (response['data'] case final Map<String, dynamic> data) {
      if (data['apiKey'] case final Map<String, dynamic> apiKey) {
        return apiKey;
      }
    }
    return response;
  }
}
