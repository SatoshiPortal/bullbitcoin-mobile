import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../data/api_key_model.dart';
import '../data/exchange_api_key_mapper.dart';
import '../data/legacy_exchange_credentials.dart';
import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_failure.dart';

/// Legacy credential lifecycle for the host's access coordinator.
abstract interface class ExchangeCredentials {
  static ExchangeCredentials open(ExchangeKeychain keychain) =>
      LegacyExchangeCredentials(secureStorage: keychain);

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
