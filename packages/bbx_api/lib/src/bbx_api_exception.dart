/// A failed Bull Bitcoin API call. Messages never quote request or response
/// payloads.
sealed class BbxApiException implements Exception {
  const BbxApiException();
}

/// The server answered with a status other than 200.
final class BbxApiHttpException extends BbxApiException {
  final int? statusCode;

  const BbxApiHttpException(this.statusCode);

  @override
  String toString() => 'BbxApiHttpException(status: $statusCode)';
}

/// The server returned a JSON-RPC error.
///
/// [apiCode] is the error's `data.apiError.code`, kept only when it is an
/// `ERR_` code so that it never carries account details.
final class BbxApiRpcException extends BbxApiException {
  final int? code;

  /// The server's text. It can quote account data, so [toString] leaves it
  /// out.
  final String? message;
  final String? apiCode;

  const BbxApiRpcException({this.code, this.message, this.apiCode});

  factory BbxApiRpcException.fromJson(Object error) => switch (error) {
    {'code': final int? code, 'message': final String? message} =>
      BbxApiRpcException(
        code: code,
        message: message,
        apiCode: _apiCode(error),
      ),
    {'code': final int? code} => BbxApiRpcException(
      code: code,
      apiCode: _apiCode(error),
    ),
    _ => BbxApiRpcException(apiCode: _apiCode(error)),
  };

  static final _apiCodePattern = RegExp(r'^ERR_[A-Z0-9_]{1,64}$');

  static String? _apiCode(Object error) => switch (error) {
    {'data': {'apiError': {'code': final String code}}}
        when _apiCodePattern.hasMatch(code) =>
      code,
    _ => null,
  };

  @override
  String toString() => 'BbxApiRpcException(code: $code)';
}

/// The bound of an order limit that an amount crossed.
enum BbxApiOrderLimitBound { minimum, maximum }

/// The server refused an order because its amount is outside a limit.
///
/// When several payment options were refused against the same bound and
/// currency, [amount] is the lowest minimum or the highest maximum: the
/// amount that makes at least one of them possible.
final class BbxApiOrderLimitException extends BbxApiRpcException {
  final BbxApiOrderLimitBound bound;
  final double amount;
  final String currency;

  const BbxApiOrderLimitException({
    required this.bound,
    required this.amount,
    required this.currency,
    super.code,
    super.apiCode,
  });

  @override
  String toString() =>
      'BbxApiOrderLimitException(bound: ${bound.name}, amount: $amount, '
      'currency: $currency)';
}

/// The server refused a Confidential SEPA order because the recipient's
/// virtual payee is not active yet (`ERR_ORD_CSRCP400`).
final class BbxApiConfidentialSepaNotActivatedException
    extends BbxApiRpcException {
  const BbxApiConfidentialSepaNotActivatedException({
    super.code,
    super.apiCode,
  });

  @override
  String toString() =>
      'BbxApiConfidentialSepaNotActivatedException(code: $code)';
}

/// The response did not have the expected shape.
final class BbxApiFormatException extends BbxApiException {
  final String reason;

  const BbxApiFormatException(this.reason);

  @override
  String toString() => 'BbxApiFormatException($reason)';
}
