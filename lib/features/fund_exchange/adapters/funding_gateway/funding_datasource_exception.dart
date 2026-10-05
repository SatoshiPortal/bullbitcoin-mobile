/// Low-level, thrown signals raised by the funding gateway for transport- and
/// protocol-level conditions it detects itself (bad status, malformed body,
/// JSON-RPC error envelope).
///
/// These are `Exception`s, not `Failure`s: they are thrown inside the data
/// layer and caught once at the gateway boundary, which maps them to a
/// `FundExchangeFailure`. They carry NO user-facing message — translation is
/// the presentation layer's job. [logMessage] reaches logs and Sentry only.
sealed class FundingDatasourceException implements Exception {
  final String? logMessage;

  const FundingDatasourceException([this.logMessage]);

  /// What the gateway's `log.warning(..., error: e)` writes, since the log
  /// stores `error.toString()`. Without this it printed `Instance of
  /// 'FundingRpcException'` and every refusal reached the log with no reason.
  ///
  /// Safe for the transport and response subclasses: their [logMessage] is
  /// always text the gateway wrote itself (an HTTP status, a shape problem).
  @override
  String toString() => '$runtimeType($logMessage)';
}

/// The call did not come back with a usable HTTP response.
final class FundingNetworkException extends FundingDatasourceException {
  const FundingNetworkException([super.logMessage]);
}

/// The response was not the JSON-RPC shape the gateway expects.
final class FundingResponseException extends FundingDatasourceException {
  const FundingResponseException([super.logMessage]);
}

/// The API answered with a JSON-RPC `error` envelope.
///
/// Only [apiCode] is stable enough to drive a user-facing message; the
/// backend's English sentence is kept in [logMessage] and never rendered.
final class FundingRpcException extends FundingDatasourceException {
  final String? apiCode;

  const FundingRpcException({this.apiCode, String? logMessage})
    : super(logMessage);

  /// The code only. [logMessage] is the backend's own sentence, and for
  /// `ERR_ORD_CSRCP400` it can name the user's IBAN; the on-device log can be
  /// shared from the logs screen, so that sentence is not written to it.
  @override
  String toString() => 'FundingRpcException(apiCode: $apiCode)';

  factory FundingRpcException.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final dataMap = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    final apiErrorValue = dataMap['apiError'];
    final apiError = apiErrorValue is Map
        ? Map<String, dynamic>.from(apiErrorValue)
        : const <String, dynamic>{};

    // Read the code tolerantly: a hard `as String?` would throw a TypeError on
    // a numeric code, escape the boundary and demote an otherwise mappable
    // error to the generic catch-all.
    final code = apiError['code'];

    return FundingRpcException(
      apiCode: code?.toString(),
      logMessage: apiError['en']?.toString() ?? json['message']?.toString(),
    );
  }
}
