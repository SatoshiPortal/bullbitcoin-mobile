import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../data/api_key_model.dart';
import '../data/exchange_api_key_mapper.dart';
import '../data/storage/exchange_credential_storage.dart';
import '../data/stored_exchange_basic_auth.dart';
import '../data/stored_exchange_credentials.dart';
import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_basic_auth.dart';
import '../domain/exchange_failure.dart';

/// Credential lifecycle for the host's access coordinator, backed by the
/// Exchange module database.
abstract interface class ExchangeCredentials {
  static ExchangeCredentials open(ExchangeCredentialStorage storage) =>
      StoredExchangeCredentials(storage: storage);

  /// The sandbox's Basic Auth in the same store.
  static ExchangeBasicAuthStore openBasicAuth(
    ExchangeCredentialStorage storage,
  ) => StoredExchangeBasicAuth(storage);

  /// Decodes the WebView handoff without exposing its protocol model.
  @useResult
  static Result<ExchangeApiKey, ExchangeFailure> decodeAuthentication(
    Object? response,
  ) {
    if (ExchangeApiKeyModel.isAuthenticationDeferred(response)) {
      return const Err(ExchangeAuthenticationDeferredFailure());
    }
    final model = ExchangeApiKeyModel.tryFromAuthResponse(response);
    if (model == null || !model.isActive) {
      return const Err(ExchangeAuthenticationFailure());
    }
    return ExchangeApiKeyMapper.toDomain(model)
        .mapErr((_) => const ExchangeAuthenticationFailure());
  }

  /// Reads at point of use. Absence and inactivity are normal signed-out states.
  /// Storage failures are distinct and must never erase the stored session.
  @useResult
  Future<Result<String?, ExchangeFailure>> readActiveApiKey({
    required bool isTestnet,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> saveApiKey(
    ExchangeApiKey apiKey, {
    required bool isTestnet,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> deleteApiKey({required bool isTestnet});
}
