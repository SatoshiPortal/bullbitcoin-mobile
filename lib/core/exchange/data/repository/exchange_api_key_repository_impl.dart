import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
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
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeApiKeyRepositoryImpl({required this._bullbitcoinApiKeyDatasource});

  @override
  Future<Result<void, ExchangeApiKeyFailure>> saveApiKey(
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  }) async {
    try {
      final apiKeyModel = ExchangeApiKeyModel.fromJson(
        _unwrapApiKeyPayload(apiKeyResponseData),
      );

      await _bullbitcoinApiKeyDatasource.store(
        apiKeyModel,
        isTestnet: isTestnet,
      );
      return const Ok(null);
    } catch (e, st) {
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
      await _bullbitcoinApiKeyDatasource.delete(isTestnet: isTestnet);
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
