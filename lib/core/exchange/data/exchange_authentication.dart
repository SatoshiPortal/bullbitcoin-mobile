import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_exceptions.dart';
import 'package:primitives/primitives.dart';

/// A transport capability, wired by the composition root, with no key cache.
typedef ReadExchangeApiKey =
    Future<Result<String?, ExchangeApiKeyFailure>> Function();

/// A sanitized transport refusal; never retains request or storage payloads.
final class ExchangeAuthenticationException implements Exception {
  final ExchangeApiKeyFailure? failure;

  const ExchangeAuthenticationException([this.failure]);

  bool get isUnauthenticated => failure == null;

  @override
  String toString() => isUnauthenticated
      ? 'Exchange authentication required'
      : 'Exchange credential unavailable';
}

/// The refusal [error] is, or null when it is not one.
///
/// A refusal is thrown directly by the repositories that predate `Result`; the
/// transport itself reports credential failures as values.
ExchangeAuthenticationException? exchangeAuthenticationException(Object error) {
  if (error is ExchangeAuthenticationException) return error;
  return null;
}

/// Compatibility for existing throwing repository contracts. New Result-based
/// contracts translate the failure into their own failure family instead.
void rethrowExchangeAuthentication(Object error, StackTrace trace) {
  if (error is Error) {
    Error.throwWithStackTrace(error, error.stackTrace ?? StackTrace.current);
  }
  if (error is ExchangeCredentialUnavailableException) {
    Error.throwWithStackTrace(error, trace);
  }
  final refusal = exchangeAuthenticationException(error);
  if (refusal != null) {
    Error.throwWithStackTrace(
      refusal.isUnauthenticated
          ? ApiKeyNotFoundException()
          : const ExchangeCredentialUnavailableException(),
      trace,
    );
  }
}
