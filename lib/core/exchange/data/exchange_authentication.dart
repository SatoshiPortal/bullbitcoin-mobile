import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart';

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

/// Dio wraps interceptor refusals. Repositories translate only this known case.
ExchangeAuthenticationException? exchangeAuthenticationException(Object error) {
  if (error is ExchangeAuthenticationException) return error;
  if (error case DioException(
    error: final ExchangeAuthenticationException refusal,
  )) {
    return refusal;
  }
  return null;
}

/// Compatibility for existing throwing repository contracts. New Result-based
/// contracts translate the refusal into their own failure family instead.
void rethrowExchangeAuthentication(Object error, StackTrace trace) {
  if (error is Error) {
    Error.throwWithStackTrace(error, error.stackTrace ?? StackTrace.current);
  }
  if (error case DioException(
    error: final Error bug,
    stackTrace: final trace,
  )) {
    Error.throwWithStackTrace(bug, trace);
  }
  final refusal = exchangeAuthenticationException(error);
  if (refusal != null) {
    Error.throwWithStackTrace(
      refusal.isUnauthenticated ? ApiKeyNotFoundException() : refusal,
      trace,
    );
  }
}
