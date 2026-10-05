import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

/// The stored-session side of the exchange API. Implementations are the
/// `try/catch` boundary: they log the raw reason and return a sanitized
/// [ExchangeApiKeyFailure] that never carries key material.
abstract interface class ExchangeApiKeyRepository {
  @useResult
  Future<Result<void, ExchangeApiKeyFailure>> saveApiKey(
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  });

  @useResult
  Future<Result<void, ExchangeApiKeyFailure>> deleteApiKey({
    required bool isTestnet,
  });
}
