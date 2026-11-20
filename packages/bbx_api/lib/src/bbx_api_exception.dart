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
final class BbxApiRpcException extends BbxApiException {
  final int? code;

  /// The server's text. It can quote account data, so [toString] leaves it
  /// out.
  final String? message;

  const BbxApiRpcException({this.code, this.message});

  factory BbxApiRpcException.fromJson(Object error) => switch (error) {
    {'code': final int? code, 'message': final String? message} =>
      BbxApiRpcException(code: code, message: message),
    {'code': final int? code} => BbxApiRpcException(code: code),
    _ => const BbxApiRpcException(),
  };

  @override
  String toString() => 'BbxApiRpcException(code: $code)';
}

/// The response did not have the expected shape.
final class BbxApiFormatException extends BbxApiException {
  final String reason;

  const BbxApiFormatException(this.reason);

  @override
  String toString() => 'BbxApiFormatException($reason)';
}
